{ config, lib, dream2nix, pkgs, ... }:
let
  cfg = config.cog;

  # conditional overrides: only active when a lib is in use
  pipOverridesModule = { config, lib, ... }:
    let
      overrides = import ./overrides.nix;
      metadata = config.lock.content.fetchPipMetadata.sources;
    in {
      pip.drvs = lib.mapAttrs (name: info: overrides.${name} or { }) metadata;
    };

  cog_yaml = pkgs.writeTextFile {
    name = "cog.yaml";
    text = builtins.toJSON { inherit (cfg) predict; };
    destination = "/src/cog.yaml";
  };
in {
  imports = [
    ./interface.nix
    ({ config, ... }: { public.config = config; })
  ];
  config = {
    public = pkgs.dockerTools.streamLayeredImage {
      inherit (cfg) name;
      # glibc.out is needed for gpu
      contents = with pkgs;
        [
          bashInteractive
          busybox
          config.python-env.public.pyEnv
          cog_yaml
          glibc.out
        ] ++ cfg.system_packages;
      config = {
        Entrypoint = [ "${pkgs.tini}/bin/tini" "--" ];
        EXPOSE = 5000;
        CMD = [ "python" "-m" "cog.server.http" ];
        WorkingDir = "/src";
        # todo: my cog doesn't like run.cog.config
        # todo: extract openapi schema in nix build (optional?)
        Labels."org.cogmodel.config" =
          builtins.toJSON { build.gpu = cfg.build.gpu; };
      };
      # needed for gpu:
      extraCommands = "mkdir tmp";
    };
    lock = {
      inherit (config.python-env.public.config.lock) fields invalidationData;
    };
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
