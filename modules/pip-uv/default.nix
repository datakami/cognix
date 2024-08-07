{ lib, config, dream2nix, packageSets, ... }:
let
  cfg = config.pip;
  pkgs = packageSets.nixpkgs;
  # https://github.com/astral-sh/uv/issues/3276
  patchTorch = builtins.map
    (y: if builtins.match "torch==[0-9.]+$" y == [ ] then "${y}.*" else y);
  constraintsArgs = lib.optionals (cfg.constraintsList != [ ]) [
    "--constraint"
    (builtins.toFile "constraints.txt" (lib.concatMapStrings (x: ''
      ${x}
    '') cfg.constraintsList))
  ];
  overridesArgs = lib.optionals (cfg.overridesList != [ ]) [
    "--override"
    (builtins.toFile "overrides.txt" (lib.concatMapStrings (x: ''
      ${x}
    '') cfg.overridesList))
  ];
  extraArgs = constraintsArgs ++ overridesArgs ++ cfg.uv.extraArgs;
in {
  options.pip = with lib; {
    uv = {
      enable = mkOption {
        type = types.bool;
        description = "use uv solver";
        default = true;
      };
      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra arguments to pass the the `uv` solver.";
      };
    };
    constraintsList = mkOption {
      type = types.listOf types.str;
      description = ''
        Constrain versions using the given requirements.

        Constraints are `requirements.txt`-like entries that only control the _version_ of a requirement that's installed. However, including a package in constraints will _not_ trigger the installation of that package.
      '';
      default = [ ];
    };
    overridesList = mkOption {
      type = types.listOf types.str;
      description = ''
        Override versions using the given requirements files.

        Overrides specify a specific version of a requirement to be installed, regardless of the requirements declared by any constituent package, and regardless of whether this would be considered an invalid resolution.

        While constraints are _additive_, in that they're combined with the requirements of the constituent packages, overrides are _absolute_, in that they completely replace the requirements of the constituent packages.
      '';
      default = [ ];
    };
  };
  imports = [
    dream2nix.modules.dream2nix.assertions
    dream2nix.modules.dream2nix.deps
    dream2nix.modules.dream2nix.lock
  ];
  config = lib.mkMerge [
    {
      assertions = [{
        assertion = (cfg.constraintsList != [ ] || cfg.overridesList != [ ]) -> cfg.uv.enable;
        message =
          "specifying pip constraintsList or overridesList requires the `uv` solver via pip.uv.enable = true";
      }];
    }
    (lib.mkIf cfg.uv.enable {
      deps.fetchPipMetadataScript =
        pkgs.writeShellScript "fetch-pip-metadata-uv" ''
          export UV_DUMP_DREAM2NIX="$out"
          ${lib.foldlAttrs (acc: name: value:
            acc + "\nexport " + lib.toShellVar name value) "" cfg.env}
          ${pkgs.uv}/bin/uv pip install \
             --dry-run \
             --reinstall \
             --index-strategy unsafe-highest \
             --break-system-packages \
             ${
               lib.optionalString (cfg.pypiSnapshotDate != null)
               "--exclude-newer ${cfg.pypiSnapshotDate}"
             } \
             --python ${config.deps.python}/bin/python \
             ${lib.escapeShellArgs extraArgs} \
             ${
               lib.escapeShellArgs
               (lib.concatMap (x: [ "-r" x ]) cfg.requirementsFiles)
             } \
             ${lib.escapeShellArgs (patchTorch cfg.requirementsList)}
        '';
      lock.invalidationData.solver = "uv";
      lock.invalidationData.extraArgs = extraArgs;

      # workaround uv not having git hashes yet
      deps.fetchgit = {
        url, rev, sha256
      }: builtins.fetchGit { inherit url rev; }; # allRefs = true; };

    })
  ];
}
