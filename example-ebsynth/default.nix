{ pkgs, ... }:
let
  # has a custom system dependency:
  ebsynth = pkgs.callPackage ({ stdenv, lib, fetchFromGitHub }:
    stdenv.mkDerivation {
      src = fetchFromGitHub {
        owner = "jamriska";
        repo = "ebsynth";
        rev = "2f5c97c0c21a86bb7334dee61453623e6a3d41c3";
        hash = "sha256-M+dTgvAaRwGaAYo8cAJ1IrKKtMhzc8mI+LXZXE6Ivko=";
      };
      pname = "ebsynth";
      version = "2019-05-10";
      buildPhase = "./build-linux-cpu_only.sh";
      installPhase = ''
        mkdir -p $out/bin
        mv bin/ebsynth $out/bin/ebsynth
      '';
    }) { };
in {
  cog = {
    name = "ebsynth-cpu";
    build.gpu = false;
    system_packages = [ ebsynth ];
    python_version = "3.10";
    python_packages = [ ];
    python_snapshot_date = "2023-10-05";
    predict = "${./predict.py}:Predictor";
    projectRoot = ./.; # lock file
  };
}
