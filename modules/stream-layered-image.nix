{ config, lib, dream2nix, packageSets, ... }:
let cfg = config.dockerTools.streamLayeredImage;
    pkgs = packageSets.nixpkgs;
    # todo: upstream 'extraJSONFile' into nix docker-tools
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/docker/default.nix#L1015
    streamScript = pkgs.writers.writePython3 "stream" {} (pkgs.path + "/pkgs/build-support/docker/stream_layered_image.py");
    patchJson = img: extraJSON: pkgs.runCommand "patched-${img.imageName}-conf.json" {
      preferLocalBuild = true;
      nativeBuildInputs = [ pkgs.jq ];
    } ''
      outName="$(basename "$out")"
      outHash=$(echo "$outName" | cut -d - -f 1)
      json_path=$(grep -o '/nix/store/[^ ]*-conf.json' < ${img})
      jq -s '.[0] * .[1] + {
        "repo_tag": $repo_tag
      }' --arg repo_tag "${img.imageName}:$outHash" \
      "$json_path" "${extraJSON}" > $out
    '';
    patchLayeredImage = img: extraJSON: pkgs.runCommand "stream-${img.imageName}" {
      passthru = img.passthru // { wrapped = img; };
      preferLocalBuild = true;
      nativeBuildInputs = [ pkgs.makeWrapper ];
    } ''
      makeWrapper ${streamScript} $out --add-flags ${patchJson img extraJSON}
    '';
in
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
    extraJSONFile = mkOption {
      default = null;
      type = types.nullOr types.path;
      description = ''
        JSON file that's merged into the stream configuration.
        Use this to add things only available at build time, such as other build results.
      '';
    };
    includeNixDB = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Whether to generate a Nix DB. The DB won't be merged between multiple stages.
      '';
    };
  };

  config.public = let
    orig_stream = packageSets.nixpkgs.dockerTools.streamLayeredImage {
      inherit (config) name;
      inherit (cfg)
        tag fromImage contents config architecture
        created extraCommands fakeRootCommands enableFakechroot
        maxLayers includeStorePaths passthru;
    };
  in
    (if cfg.extraJSONFile != null then
      patchLayeredImage orig_stream cfg.extraJSONFile
    else
      orig_stream) // { inherit (config) name; };
  # todo base json, customisation layer deps!
  config.dockerTools.streamLayeredImage.extraCommands = lib.mkIf cfg.includeNixDB ''
    echo "Generating the nix database..."
    echo "Warning: only the database of the deepest Nix layer is loaded."
    echo "         If you want to use nix commands in the container, it would"
    echo "         be better to only have one layer that contains a nix store."

    export NIX_REMOTE=local?root=$PWD
    # A user is required by nix
    # https://github.com/NixOS/nix/blob/9348f9291e5d9e4ba3c4347ea1b235640f54fd79/src/libutil/util.cc#L478
    export USER=nobody
    ${pkgs.buildPackages.nix}/bin/nix-store --load-db < ${pkgs.closureInfo {rootPaths = cfg.contents;}}/registration
    # Reset registration times to make the image reproducible
    ${pkgs.buildPackages.sqlite}/bin/sqlite3 nix/var/nix/db/db.sqlite "UPDATE ValidPaths SET registrationTime = ''${SOURCE_DATE_EPOCH}"

    mkdir -p nix/var/nix/gcroots/docker/
    for i in ${lib.concatStringsSep " " cfg.contents}; do
    ln -s $i nix/var/nix/gcroots/docker/$(basename $i)
    done;
  '';
}
