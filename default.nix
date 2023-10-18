{ pkgs, dream2nix, projectRoot }:
package:
dream2nix.lib.evalModules {
  packageSets.nixpkgs = pkgs;
  modules = [
    ./modules/cog.nix
    package
    {
      _module.args = { inherit pkgs; };
      paths = { inherit projectRoot package; };
      cog.name = pkgs.lib.mkDefault (builtins.baseNameOf package);
    }
  ];
}
