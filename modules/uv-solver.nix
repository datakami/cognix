{ lib, config, packageSets, ... }: let
  cfg = config.pip.uv;
  pkgs = packageSets.nixpkgs;
  # bug: torch==2.1.0 does not resolve to torch==2.1.0+cpu
  patchTorch = builtins.map (y: if builtins.match "torch==[0-9\.]+$" y == [] then "${y}.*" else y);
  constraintsArgs = lib.optionals (cfg.constraints != []) [
    "--constraint"
    (builtins.toFile "constraints.txt" (lib.concatMapStrings (x: "${x}\n") cfg.constraints))
  ];
  overridesArgs = lib.optionals (cfg.overrides != []) [
    "--override"
    (builtins.toFile "overrides.txt" (lib.concatMapStrings (x: "${x}\n") cfg.overrides))
  ];
  extraArgs = constraintsArgs ++ overridesArgs ++ cfg.extraArgs;
in {
  # todo: support env
  options.pip.uv = with lib; {
    enable = mkEnableOption "use uv solver";
    overrides = mkOption {
      type = types.listOf types.str;
      default = [];
    };
    constraints = mkOption {
      type = types.listOf types.str;
      default = [];
    };
    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [];
    };
  };
  config = lib.mkIf cfg.enable {
    deps.fetchPipMetadataScript = pkgs.writeShellScript "fetch-pip-metadata-uv" ''
      export UV_DUMP_DREAM2NIX="$out"
      ${pkgs.uv}/bin/uv pip install \
         --dry-run \
         --reinstall \
         --index-strategy unsafe-highest \
         --break-system-packages \
         ${lib.optionalString (config.pip.pypiSnapshotDate != null) "--exclude-newer ${config.pip.pypiSnapshotDate}"} \
         --python ${config.deps.python}/bin/python \
         ${lib.escapeShellArgs extraArgs} \
         ${lib.escapeShellArgs (patchTorch config.pip.requirementsList)}
    '';
    lock.invalidationData.solver = "uv";
    lock.invalidationData.extraArgs = extraArgs;
  };
}
