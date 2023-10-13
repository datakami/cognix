# usage: $(nix-build -A img) | docker load
# cog predict ebsynth-cpu:.....
{ pkgs, dream2nix, projectRoot }:
packageDir:
let
  config = (import packageDir { inherit pkgs; }).cog;
in
rec {
  img = pkgs.dockerTools.streamLayeredImage {
    inherit (config) name;
    # glibc.out is needed for gpu
    contents = with pkgs; [ bashInteractive busybox python-env.pyEnv cog_yaml glibc.out ] ++ config.system_packages;
    config = {
      Entrypoint = [ "${pkgs.tini}/bin/tini" "--" ];
      EXPOSE = 5000;
      CMD = [ "python" "-m" "cog.server.http" ];
      WorkingDir = "/src";
      # todo: my cog doesn't like run.cog.config
      # todo: extract openapi schema in nix build (optional?)
      Labels."org.cogmodel.config" = builtins.toJSON { inherit (config) build; };
    };
    # needed for gpu:
    extraCommands = "mkdir tmp";
  };
  cog_yaml = pkgs.writeTextFile {
    name = "cog.yaml";
    text = builtins.toJSON { inherit (config) predict; };
    destination = "/src/cog.yaml";
  };
  # conditional overrides: only active when a lib is in use
  pipOverridesModule = { dream2nix, config, lib, ... }: let
    overrides = import ./overrides.nix;
    metadata = config.lock.content.fetchPipMetadata.sources;
  in {
    pip.drvs = lib.mapAttrs (name: info: overrides.${name} or {}) metadata;
  };
  python-env = dream2nix.lib.evalModules {
    packageSets.nixpkgs = pkgs;
    modules = [
      ({ dream2nix, ... }: {
        imports = [ dream2nix.modules.dream2nix.pip pipOverridesModule ];
        paths = {
          inherit projectRoot;
          package = packageDir;
        };
        name = "cog-docker-env";
        version = "0.1.0";
        pip = {
          pypiSnapshotDate = config.python_snapshot_date;
          requirementsList = [ "cog==0.8.6" ] ++ config.python_packages;
          #requirementsList = [ "${./inputs}/cog-0.0.1.dev-py3-none-any.whl" ];
          flattenDependencies = true; # todo: why?
          drvs = {};
        };
      })
    ];
  };
}
