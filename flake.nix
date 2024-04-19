{
  description = "Building cog images deterministically using Nix";
  inputs = {
    dream2nix.url = "github:yorickvp/dream2nix";
    nixpkgs.follows = "dream2nix/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, dream2nix, nixpkgs, flake-parts, rust-overlay }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      # debug = true;
      flake.templates.default = {
        path = ./template;
        description = "A single cognix project";
      };
      flake.lib.singleCognixFlake = { self, cognix, ... }@inputs:
        name:
        cognix.lib.cognixFlake inputs { ${name} = "${self}"; };
      flake.lib.cognixFlake = { self, cognix, ... }:
        packages: {
          packages.x86_64-linux = let
            calledPackages = builtins.mapAttrs (name: path:
              cognix.legacyPackages.x86_64-linux.callCognix {
                paths.projectRoot = self;
                inherit name;
              } path) packages;
          in if (builtins.length (builtins.attrNames calledPackages) == 1) then
            calledPackages // {
              # if there's just 1 package, alias to 'default'
              default = calledPackages.${
                  builtins.head (builtins.attrNames calledPackages)
                };
            }
          else
            calledPackages;
          devShells.x86_64-linux.default =
            cognix.devShells.x86_64-linux.default;
          apps.x86_64-linux.default = {
            type = "app";
            program = "${cognix.packages.x86_64-linux.default}/bin/cognix";
          };
        };
      perSystem = { system, pkgs, config, ... }:
        let
          callCognix = config.legacyPackages.callCognix {
            paths.projectRoot = ./.;
          };
        in {
          _module.args.pkgs = import nixpkgs {
            config.allowUnfree = true;
            inherit system;
            overlays = [
              (import rust-overlay)
              (final: prev: {
                pget = prev.callPackage ./pkgs/pget.nix { };
                cognix-weights = prev.callPackage ./pkgs/cognix-weights {};
                cognix-cli = prev.callPackage ./pkgs/cognix-cli {};
                cog = prev.callPackage ./pkgs/cog.nix {};
                uv = prev.callPackage ./pkgs/uv.nix {
                  rustPlatform = prev.makeRustPlatform {
                    cargo = prev.rust-bin.stable.latest.minimal;
                    rustc = prev.rust-bin.stable.latest.minimal;
                  };
                };
                lib = prev.lib.extend (finall: prevl: {
                  trivial = prevl.trivial // {
                    revisionWithDefault = default: nixpkgs.rev or default;
                  };
                });
                stream_layered_image = prev.callPackage ./pkgs/stream_layered_image/default.nix {};
              })
            ];
          };
          devShells.weights = with pkgs; mkShell {
            nativeBuildInputs = [ pyright ruff python3 ];
            propagatedBuildInputs = with python3.pkgs; [ pygit2 google-cloud-storage ];
          };
          devShells.cli = with pkgs; mkShell {
            nativeBuildInputs = [ pyright ruff python3 ];
            propagatedBuildInputs = with python3.pkgs; [ click ];
          };
          devShells.default = with pkgs; mkShell {
            nativeBuildInputs = [ cognix-cli ];
          };
          devShells.stream_layered_image = with pkgs; mkShell {
            nativeBuildInputs = [ go gopls ];
          };
          packages.default = pkgs.cognix-cli;
          checks.default = pkgs.linkFarm "all-checks" (pkgs.lib.mapAttrsToList
            (name: path: {
              inherit name;
              path = if pkgs.lib.isDerivation path then path else "/dev/null";
            }) config.legacyPackages);
          legacyPackages = {
            inherit (pkgs) pget cognix-weights cognix-cli cog stream_layered_image uv;
            callCognix = import ./default.nix {
              inherit pkgs dream2nix;
            };

            ebsynth-cpu = callCognix ./examples/ebsynth-cpu;
            torch-demo = callCognix ./examples/torch-demo;
            gte-small = callCognix ./examples/gte-small;
            gte-large = callCognix ./examples/gte-large;
            # stopped working, weights are gated :(
            # jina-embeddings-v2-small-en = callCognix ./examples/jina-embeddings-v2-small-en;
            # jina-embeddings-v2-base-en = callCognix ./examples/jina-embeddings-v2-base-en;
          };
        };
    };
}
