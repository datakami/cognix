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
  cudaPackagesByVersion = {
    "11.0" = pkgs.cudaPackages_11_0;
    "11.1" = pkgs.cudaPackages_11_1;
    "11.3" = pkgs.cudaPackages_11_3;
    "11.5" = pkgs.cudaPackages_11_5;
    "11.6" = pkgs.cudaPackages_11_6;
    "11.7" = pkgs.cudaPackages_11_7;
    "11.8" = pkgs.cudaPackages_11_8;
    "12.1" = pkgs.cudaPackages_12_1;
    "12.2" = pkgs.cudaPackages_12_2;
    "12.3" = pkgs.cudaPackages_12_3;
    "12.4" = pkgs.cudaPackages_12_4;
  };
  python3 = config.python-env.deps.python;
in {
  config = lib.mkMerge [
    (lib.mkIf (knowsTorch) {
      cog.build.cuda = lib.mkDefault (if cfg.gpu then
        (defaultTorchCudas.${torchVersion} or (throw
          "Unknown torch version ${torchVersion}, specify build.cuda manually"))
      else
        null);

      cog.build.python_extra_index_urls = if cfg.gpu then
        [ (toTorchIndex cfg.cuda) ]
      else
        [ "https://download.pytorch.org/whl/cpu" ];
    })
    (lib.mkIf (!cfg.gpu) { cog.build.cuda = lib.mkDefault null; })
    {
      cognix.cudaPackages = lib.mkDefault cudaPackagesByVersion.${config.cog.build.cuda};
    }
    (lib.mkIf (config.cognix.merge-native.cublas != false) {
      assertions = [ {
        assertion = config.python-env.pip.uv.enable;
        message = "merge-native requires python-env.pip.uv.enable = true";
      } ];

      python-env.pip = let
        pyPkg = "nvidia-cublas-cu12";
        pkg = config.cognix.cudaPackages.libcublas;
      in {
        overrides.${pyPkg}.mkDerivation.postInstall = ''
          pushd $out/${python3.sitePackages}/nvidia/cublas/lib
          for f in ./*.so.12; do
            chmod +w "$f"
            rm $f
            ln -s ${pkg.lib}/lib/$f ./$f
          done
          popd
        '';

        overridesList = lib.mkIf (config.cognix.merge-native.cublas == "force")
          [ "${pyPkg}==${pkg.version}" ];
        constraintsList = [ "${pyPkg}==${pkg.version}" ];
      };
    })
    (lib.mkIf (config.cognix.merge-native.cudnn != false) {
      assertions = [ {
        assertion = config.python-env.pip.uv.enable;
        message = "merge-native requires python-env.pip.uv.enable = true";
      } ];

      python-env.pip = let
        pyPkg = "nvidia-cudnn-cu12";
        pkg = config.cognix.cudaPackages.cudnn;
      in {
        overrides.${pyPkg}.mkDerivation.postInstall = ''
          pushd $out/${python3.sitePackages}/nvidia/cudnn/lib
          for f in ./*.so.8; do
            chmod +w "$f"
            rm $f
            ln -s ${pkg.lib}/lib/$f ./$f
          done
          popd
        '';

        overridesList = lib.mkIf (config.cognix.merge-native.cudnn == "force")
          [ "${pyPkg}==${pkg.version}" ];
        constraintsList = [ "${pyPkg}==${pkg.version}" ];
      };
    })
  ];
}
