{
  description = "Building cog images deterministically using Nix";
  inputs = {
    dream2nix.url = "github:yorickvp/dream2nix";
    nixpkgs.follows = "dream2nix/nixpkgs";
    flake-parts.follows = "dream2nix/flake-parts";
  };

  outputs = { self, dream2nix, nixpkgs, flake-parts }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      # debug = true;
      perSystem = { system, pkgs, config, ... }:
        let inherit (config.legacyPackages) callCognix;
        in {
          _module.args.pkgs = import nixpkgs {
            config.allowUnfree = true;
            inherit system;
            overlays = [
              (final: prev: {
                pget = prev.callPackage ./pkgs/pget.nix { };
                cognix-weights = prev.callPackage ./pkgs/cognix-weights {};
                cog = prev.callPackage ./pkgs/cog.nix {};
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
          legacyPackages = {
            inherit (pkgs) pget cognix-weights cog;
            callCognix = import ./default.nix {
              inherit pkgs dream2nix;
              paths.projectRoot = ./.;
            };

            ebsynth-cpu = callCognix ./examples/ebsynth-cpu;
            torch-demo = callCognix ./examples/torch-demo;
            gte-small = callCognix ./examples/gte-small;
            gte-large = callCognix ./examples/gte-large;
            jina-embeddings-v2-small-en = callCognix ./examples/jina-embeddings-v2-small-en;
            jina-embeddings-v2-base-en = callCognix ./examples/jina-embeddings-v2-base-en;
          };
        };
    };
}
