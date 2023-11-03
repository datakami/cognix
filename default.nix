let
  yamlModule = { yj, runCommand, file }:
    let
      json = runCommand "file.json" { } ''
        ${yj}/bin/yj < ${file} > $out
      '';
    in {
      # set location for errors
      _file = file;
      cog = builtins.fromJSON (builtins.readFile json);
    };

  inherit (builtins) pathExists;

  # take a cog location, return a dream2nix module that imports it
  packageModule = package:
    ({ lib, packageSets, ... }: {
      imports = [
        (if pathExists (package + "/default.nix") then package else { })
        (if pathExists (package + "/cog.yaml") then
          yamlModule {
            file = (package + "/cog.yaml");
            inherit (packageSets.nixpkgs) runCommand yj;
          }
        else
          { })
      ];
      assertions = [{
        assertion = pathExists (package + "/default.nix")
          || pathExists (package + "/cog.yaml");
        message =
          "Path name ${package} should contain 'default.nix' or 'cog.yaml'";
      }];
      _module.args.pkgs = packageSets.nixpkgs;
      paths.package = package;
      name = lib.mkDefault (baseNameOf package);
    });

in { pkgs, dream2nix }:
args: package:
dream2nix.lib.evalModules {
  packageSets.nixpkgs = pkgs;
  modules =
    [ ./modules/cog.nix ./modules/weights args (packageModule package) ];
}
