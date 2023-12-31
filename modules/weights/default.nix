{ lib, config, pkgs, ... }:
let
  inherit (config.cog) weights;

  # the basic idea:
  # - lock:
  #   - git clone huggingface
  #   - fetch everything in build_include
  #   - log everything in download_include, grab hashes from lfs files
  #   - hash and write the hash and rev to lock.json
  # - build:
  #   - same process but with rev pinned
  #   - nix checks and content-addresses by the hash
  #   - symlinked to img /src/${name} so huggingface loads work
  # - push:
  #   - push download_include files to weights bucket
  # - runtime: (not implemented)
  #   - pget download_included files, maybe check hashes
  # pkgs/cognix-weights/*.py does the heavy lifting

  toJSONFile = name: contents: builtins.toFile name (builtins.toJSON contents);

  # the drv that's used to download the weights at build-time
  weightsFetcher = spec: lock:
    pkgs.stdenv.mkDerivation {
      name = "${spec.src}-weights";
      passthru = { inherit spec lock; };
      nativeBuildInputs = [ config.deps.fetchHuggingface ];
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = lock.hash;
      buildCommand = ''
        fetchHuggingface build $out \
          ${toJSONFile "spec.json" spec} \
          ${toJSONFile "lock.json" lock}
      '';
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };

  weightsDrvs =
    lib.zipListsWith weightsFetcher weights config.lock.content.weights;

  # I was using buildEnv here, but it also needs to use the correct locations
  weightsEnv = pkgs.runCommand "weights" { }
    (lib.strings.concatMapStringsSep "\n" (weight: ''
      mkdir -p $(dirname $out/src/${weight.spec.src})
      ln -s ${weight} $out/src/${weight.spec.src}
    '') weightsDrvs);

  downloadWeights = pkgs.writeScriptBin "download-weights" ''
    #!/bin/sh
    ${config.deps.downloadWeights.run}/bin/downloadWeights /src \
      ${toJSONFile "specs.json" weights} ${toJSONFile "lock.json" config.lock.content.weights}
  '';

in {
  imports = [ ./interface.nix ];
  config = lib.mkIf (weights != [ ]) {
    deps.fetchHuggingface = pkgs.cognix-weights;
    deps.downloadWeights = pkgs.cognix-weights.override { python3 = config.python-env.deps.python; };
    # https://nix-community.github.io/dream2nix/options/lock.html
    lock = {
      invalidationData = { inherit weights; };
      fields.weights = {
        script = pkgs.writeScript "refresh-huggingface" ''
          #!/bin/sh
          ${config.deps.fetchHuggingface}/bin/fetchHuggingface lock \
            ${toJSONFile "specs.json" weights} > $out
        '';
      };
    };
    public.push-weights = pkgs.writeScriptBin "push-huggingface" ''
      #!/bin/sh
      ${config.deps.fetchHuggingface}/bin/fetchHuggingface push \
        ${toJSONFile "specs.json" weights} ${toJSONFile "lock.json" config.lock.content.weights}
    '';
    dockerTools.streamLayeredImage = {
      # debug: nix build .#thing.weights
      passthru.weights = weightsEnv;
      contents = [ weightsEnv downloadWeights ];
    };
  };
}
