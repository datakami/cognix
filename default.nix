{ pkgs, dream2nix, ... } @ args:
let
  forwardedArgs = builtins.removeAttrs args [
    "pkgs" "dream2nix"
  ];
  importYaml = file:
    let
      json = pkgs.runCommand "file.json" { } ''
        ${pkgs.yj}/bin/yj < ${file} > $out
      '';
    in (builtins.fromJSON (builtins.readFile json));

  inherit (builtins) pathExists;

in package:
dream2nix.lib.evalModules {
  packageSets.nixpkgs = pkgs;
  modules = [
    ./modules/cog.nix
    ./modules/weights
    (if pathExists (package + "/default.nix") then package else { })
    forwardedArgs
    ({ lib, packageSets, ... }: {
      _module.args.pkgs = packageSets.nixpkgs;
      paths.package = package;
      name = lib.mkDefault (baseNameOf package);
    })
    (if pathExists (package + "/cog.yaml") then {
      _file = package + "/cog.yaml";
      cog = importYaml (package + "/cog.yaml");
    } else
      { })
  ];
}
