{ config, lib, dream2nix, pkgs, ... }:
let
  cfg = config.cog;

  # conditional overrides: only active when a lib is in use
  pipOverridesModule = { config, lib, ... }:
    let
      overrides = import ./../overrides.nix;
      metadata = config.lock.content.fetchPipMetadata.sources;
    in {
      pip.drvs = lib.mapAttrs (name: info: overrides.${name} or { }) metadata;
    };

  cog_yaml = pkgs.writeTextFile {
    name = "cog.yaml";
    text = builtins.toJSON { inherit (cfg) predict; };
    destination = "/src/cog.yaml";
  };
  mapAttrNames = f: set:
    lib.listToAttrs (map (attr: { name = f attr; value = set.${attr}; }) (lib.attrNames set));
  addLabelPrefix = labels: (mapAttrNames (x: "run.cog.${x}") labels) // (mapAttrNames (x: "org.cogmodel.${x}") labels);
  # hack: replicate calls "pip -U cog" before starting
  fakePip = pkgs.writeShellScriptBin "pip" ''
    echo "$@"
  '';
  resolvedSystemPackages = map (pkg:
    if lib.isDerivation pkg then pkg else
      config.cognix.systemPackages.${pkg}) cfg.system_packages;
in {
  imports = [
    ./cog-interface.nix
    ./stream-layered-image.nix
    ({ config, ... }: { public.config = config; })
  ];
  options.openapi-spec = with lib; mkOption {
    type = types.path;
  };
  config = {
    inherit (cfg) name;
    dockerTools.streamLayeredImage = {
      # glibc.out is needed for gpu
      contents = with pkgs;
        [
          bashInteractive
          busybox
          config.python-env.public.pyEnv
          cog_yaml
          fakePip
          glibc.out
        ] ++ resolvedSystemPackages;
      config = {
        Entrypoint = [ "${pkgs.tini}/bin/tini" "--" ];
        EXPOSE = 5000;
        CMD = [ "python" "-m" "cog.server.http" ];
        WorkingDir = "/src";
        # todo: my cog doesn't like run.cog.config
        # todo: extract openapi schema in nix build (optional?)
        Labels = addLabelPrefix {
          has_init = "true";
          config = builtins.toJSON { build.gpu = cfg.build.gpu; };
          openapi_schema = builtins.readFile config.openapi-spec;
          cog_version = "0.8.6";
        };
      };
      # needed for gpu:
      extraCommands = "mkdir tmp";
    };
    lock = {
      inherit (config.python-env.public.config.lock) fields invalidationData;
    };
    openapi-spec = lib.mkDefault (pkgs.runCommandNoCC "openapi.json" {} ''
      cd ${cog_yaml}/src
      ${config.python-env.public.pyEnv}/bin/python -m cog.command.openapi_schema > $out
    '');
    python-env = {
      imports = [ dream2nix.modules.dream2nix.pip pipOverridesModule ];
      paths = { inherit (config.paths) projectRoot package; };
      name = "cog-docker-env";
      version = "0.1.0";
      pip = {
        pypiSnapshotDate = cfg.python_snapshot_date;
        requirementsList = [ "cog==0.8.6" ] ++ cfg.python_packages;
        #requirementsList = [ "${./inputs}/cog-0.0.1.dev-py3-none-any.whl" ];
        flattenDependencies = true; # todo: why?
        drvs = { };
      };
    };
  };
}
