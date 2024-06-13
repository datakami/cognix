{ config, lib, pkgs, ... }:
let
  cfg = config.cognix;
  nixConfig = ''
    experimental-features = nix-command flakes
    ${cfg.nix.extraOptions}
  '';
  registry = builtins.toJSON {
    version = 2;
    flakes = [
      {
        from = {
          id = "nixpkgs";
          type = "indirect";
        };
        to = {
          type = "github";
          owner = "NixOS";
          repo = "nixpkgs";
          rev = pkgs.lib.trivial.revisionWithDefault "nixos-unstable";
        };
      }
    ];
  };
in
{
  options.cognix = with lib; {
    includeNix = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to add Nix to the image so it can be used to install more packages at run-time.
        This also sets the NIX_PATH so nixpkgs points to the nixpkgs used in cognix.
      '';
    };
    nix.extraOptions = mkOption {
      type = types.lines;
      default = "";
      example = ''
        cores = 4
      '';
      description = ''
        Additional text appended to {file}`nix.conf` inside the image, when includeNix = true.
      '';
    };
  };
  config = lib.mkIf cfg.includeNix {
    dockerTools.streamLayeredImage = {
      includeNixDB = true;
      contents = [ pkgs.pkgsStatic.nix ];
      extraCommands = ''
        mkdir -p etc/nix
        cp ${builtins.toFile "nix.conf" nixConfig} etc/nix/nix.conf
        cp ${builtins.toFile "registry.json" registry} etc/nix/registry.json
      '';
    };

    cognix.environment.NIX_PATH = let
      nixpkgsVer = pkgs.lib.trivial.revisionWithDefault "nixos-unstable";
      in lib.mkIf config.cognix.includeNix
        "nixpkgs=https://github.com/NixOS/nixpkgs/archive/${nixpkgsVer}.tar.gz";
  };
}
