{
  description = "Building cog images deterministically using Nix";
  inputs.dream2nix.url = "github:yorickvp/dream2nix";
  inputs.nixpkgs.follows = "dream2nix/nixpkgs";

  outputs = { self, dream2nix, nixpkgs }: let
    callCognix = import ./default.nix {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inherit dream2nix;
      projectRoot = ./.;
    };
  in {
      legacyPackages.x86_64-linux = {
        ebsynth-cpu = callCognix ./examples/ebsynth-cpu;
        torch-demo = callCognix ./examples/torch-demo;
        gte-small = callCognix ./examples/gte-small;
      };
  };
}
