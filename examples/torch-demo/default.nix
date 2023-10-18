{ pkgs, ... }:
let
  # workaround: the filename needs to be right
  rename = drv: name: "${pkgs.runCommand "torch-wheel" {} ''
    mkdir $out
    ln -s ${drv} $out/${name}
  ''}/${name}";
  smaller_torch = rename (pkgs.fetchurl {
    url = "http://r2.drysys.workers.dev/torch/torch-2.0.0a0+gite9ebda2-cp310-cp310-linux_x86_64.whl";
    hash = "sha256-BT5r8mtp4PH6MQysFwYVLz58/UDjDWstgDFC1Jh8Y+Q=";
  }) "torch-2.0.0a0+gite9ebda2-cp310-cp310-linux_x86_64.whl";
  cpu_torch = rename (pkgs.fetchurl {
    url = "https://download.pytorch.org/whl/cpu/torch-2.0.1%2Bcpu-cp310-cp310-linux_x86_64.whl";
    hash = "sha256-/sJXJJugFMaGKaGZSwxuc1biDhr8d6h7mUGkDlCVKF0=";
  }) "torch-2.0.1+cpu-cp310-cp310-linux_x86_64.whl";
in
{
  cog = {
    build.gpu = true;
    python_version = "3.10";
    python_packages = [ smaller_torch "transformers" ];
    python_snapshot_date = "2023-10-05";
    predict = "${./predict.py}:Predictor";
  };
  python-env.pip.drvs.torch.mkDerivation.postInstall = ''
    rm $out/lib/python*/site-packages/torch/lib/lib{caffe2_nvrtc,torch_cuda_linalg}.so
  '';
}
