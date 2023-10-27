{
  description = "Building cog images deterministically using Nix";
  inputs = {
    dream2nix.url = "github:yorickvp/dream2nix";
    nixpkgs.follows = "dream2nix/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, dream2nix, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          config.allowUnfree = true;
          overlays =
            [ (final: prev: { pget = prev.callPackage ./pkgs/pget.nix { }; }) ];
          inherit system;
        };
        callCognix = import ./default.nix {
          inherit pkgs dream2nix;
          projectRoot = ./.;
        };
      in {
        legacyPackages = {
          ebsynth-cpu = callCognix ./examples/ebsynth-cpu;
          torch-demo = callCognix ./examples/torch-demo;
          gte-small = callCognix ./examples/gte-small;
          gte-large = callCognix ./examples/gte-large;
        } // {
          inherit (pkgs) pget;
        };
      });
}
