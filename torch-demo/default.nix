{ pkgs, ... }:
{
  cog = {
    name = "torch-demo";
    build.gpu = true;
    system_packages = [ ];
    python_version = "3.10";
    python_packages = [ "torch==2.0.1" ];
    python_snapshot_date = "2023-10-05";
    predict = "${./predict.py}:Predictor";
  };
}
