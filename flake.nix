{
  description = "Building cog images deterministically using Nix";
  inputs.dream2nix.url = "github:nix-community/dream2nix/5e2577caaf87661e29405db7e117bda57b0e749d";
  inputs.nixpkgs.follows = "dream2nix/nixpkgs";

  outputs = { self, dream2nix, nixpkgs }: {
    legacyPackages.x86_64-linux.ebsynth-cpu = import ./default.nix (rec {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inherit dream2nix;
      config = (import ./example-ebsynth { inherit pkgs; }).cog;
    });
    legacyPackages.x86_64-linux.torch-demo = import ./default.nix (rec {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inherit dream2nix;
      config = (import ./torch-demo { inherit pkgs; }).cog;
    });
  };
}
