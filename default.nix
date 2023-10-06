# usage: $(nix-build -A img) | docker load
# cog predict ebsynth-cpu:.....
{ pkgs, dream2nix, config }:
rec {
  img = pkgs.dockerTools.streamLayeredImage {
    inherit (config) name;
    contents = with pkgs; [ bashInteractive busybox python-env.pyEnv cog_yaml ] ++ config.system_packages;
    config = {
      Entrypoint = [ "${pkgs.tini}/bin/tini" "--" ];
      EXPOSE = 5000;
      CMD = [ "python" "-m" "cog.server.http" ];
      WorkingDir = "/src";
      # todo: my cog doesn't like run.cog.config
      # todo: extract openapi schema in nix build (optional?)
      Labels."org.cogmodel.config" = builtins.toJSON { inherit (config) build; };
    };
  };
  cog_yaml = pkgs.writeTextFile {
    name = "cog.yaml";
    text = builtins.toJSON { inherit (config) predict; };
    destination = "/src/cog.yaml";
  };
  python-env = dream2nix.lib.evalModules {
    packageSets.nixpkgs = pkgs;
    modules = [
      ({ dream2nix, ... }: {
        imports = [ dream2nix.modules.dream2nix.pip ];
        paths = {
          inherit (config) projectRoot;
          package = ".";
        };
        name = "cog-docker-env";
        version = "0.1.0";
        pip = {
          pypiSnapshotDate = config.python_snapshot_date;
          requirementsList = [ "cog==0.8.6" ] ++ config.python_packages;
          #requirementsList = [ "${./inputs}/cog-0.0.1.dev-py3-none-any.whl" ];
          flattenDependencies = true; # todo: why?
        };
      })
    ];
  };
}
