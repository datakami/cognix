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
              (final: prev: {
                pget = prev.callPackage ./pkgs/pget.nix { };
                cognix-weights = prev.callPackage ./pkgs/cognix-weights {};
                cognix-cli = prev.callPackage ./pkgs/cognix-cli {};
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
          devShells.default = with pkgs; mkShell {
            nativeBuildInputs = [ cognix-cli ];
          };
          packages.default = pkgs.cognix-cli;
          legacyPackages = {
            inherit (pkgs) pget cognix-weights cognix-cli cog;
            callCognix = import ./default.nix {
              inherit pkgs dream2nix;
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
