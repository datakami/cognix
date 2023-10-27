{ config, lib, dream2nix, pkgs, ... }:
let
  cfg = config.cog.build;
  defaultTorchCudas = {
    "1.10.0" = "11.3";
    "1.10.2" = "11.3";
    "1.11.0" = "11.5";
    "1.12.0" = "11.6";
    "1.12.1" = "11.6";
    "1.13.0" = "11.7";
    "1.13.1" = "11.7";
    "2.0.0" = "11.7";
    "2.0.1" = "11.8";
    "2.1.0" = "12.0";
  };
  toTorchIndex = v:
    "https://download.pytorch.org/whl/cu${
      builtins.replaceStrings [ "." ] [ "" ] v
    }";
  torches = builtins.filter (lib.hasPrefix "torch==") cfg.python_packages;
  knowsTorch = torches != [ ];
  torchVersion = builtins.substring 7 (-1) (builtins.head torches);
in {
  config = lib.mkIf knowsTorch {
    cog.build.cuda = lib.mkDefault (if cfg.gpu then
      (defaultTorchCudas.${torchVersion} or (throw
        "Unknown torch version ${torchVersion}, specify build.cuda manually"))
    else
      null);

    cog.build.python_extra_index_urls = if cfg.gpu then
      [ (toTorchIndex cfg.cuda) ]
    else
      [ "https://download.pytorch.org/whl/cpu" ];
  };
}
