{ pkgs, dream2nix, projectRoot }:
package:
let
  importYaml = file:
    let
      json = pkgs.runCommandNoCC "file.json" {} ''
        ${pkgs.yj}/bin/yj < ${file} > $out
      '';
    in
      (builtins.fromJSON (builtins.readFile json));
in
dream2nix.lib.evalModules {
  packageSets.nixpkgs = pkgs;
  modules = [
    ./modules/cog.nix
    (if builtins.pathExists (package + "/default.nix") then package else {})
    {
      _module.args = { inherit pkgs; };
      paths = { inherit projectRoot package; };
      name = pkgs.lib.mkDefault (builtins.baseNameOf package);
    }
    (if builtins.pathExists (package + "/cog.yaml") then {
      _file = package + "/cog.yaml";
      cog = importYaml (package + "/cog.yaml");
    } else {})
  ];
}
