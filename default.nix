{ pkgs, dream2nix, projectRoot }:
package:
dream2nix.lib.evalModules {
  packageSets.nixpkgs = pkgs;
  modules = [
    ./module.nix
    package
    {
      _module.args = { inherit pkgs; };
      paths = { inherit projectRoot package; };
    }
  ];
}
