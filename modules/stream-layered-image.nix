{ config, lib, dream2nix, packageSets, ... }:
let cfg = config.dockerTools.streamLayeredImage; in
{
  options.dockerTools.streamLayeredImage = with lib; {
    tag = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Image tag, the Nix's output hash will be used if null";
    };
    fromImage = mkOption {
      default = null;
      type = types.nullOr types.str;
      description = "Parent image, to append to.";
    };
    contents = mkOption {
      description = "Files to put on the image (a nix store path or list of paths).";
      default = [ ];
      type = types.listOf types.package;
    };
    config = mkOption {
      default = { };
      type = types.attrsOf types.anything;
      description = "Docker config; e.g. what command to run on the container.";
    };
    architecture = mkOption {
      default = packageSets.nixpkgs.go.GOARCH;
      type = types.str;
      description = "Image architecture, defaults to the architecture of the `hostPlatform` when unset";
    };
    created = mkOption {
      default = "1970-01-01T00:00:01Z";
      type = types.str;
      description = ''
        Time of creation of the image. Passing "now" will
        make the created date be the time of building.
      '';
    };
    extraCommands = mkOption {
      default = "";
      type = types.lines;
      description = "Optional bash script to run on the files prior to fixturizing the layer.";
    };
    fakeRootCommands = mkOption {
      default = "";
      type = types.lines;
      description = ''
        Optional bash script to run inside fakeroot environment.
        Could be used for changing ownership of files in customisation layer.
      '';
    };
    enableFakechroot = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Whether to run fakeRootCommands in fakechroot as well, so that they
        appear to run inside the image, but have access to the normal Nix store.
        Perhaps this could be enabled on by default on pkgs.stdenv.buildPlatform.isLinux
      '';
    };
    maxLayers = mkOption {
      default = 100;
      type = types.int;
      description = ''
        We pick 100 to ensure there is plenty of room for extension. I
        believe the actual maximum is 128.
        '';
      };
    includeStorePaths = mkOption {
      default = true;
      type = types.bool;
      description = ''
        Whether to include store paths in the image. You generally want to leave
        this on, but tooling may disable this to insert the store paths more
        efficiently via other means, such as bind mounting the host store.
        '';
      };
    passthru = mkOption {
      default = {};
      type = types.attrsOf types.anything;
      description = "Passthru arguments for the underlying derivation.";
    };
  };

  config.public = (packageSets.nixpkgs.dockerTools.streamLayeredImage {
    inherit (config) name;
    inherit (cfg)
      tag fromImage contents config architecture
      created extraCommands fakeRootCommands enableFakechroot
      maxLayers includeStorePaths passthru;
  }) // { inherit (config) name; };
}
