{
  cog.build.python_snapshot_date = "2023-10-05";
  cog.build.cog_version = "0.8.6";
  python-env.pip.drvs.torch.mkDerivation.postInstall = ''
    rm $out/lib/python*/site-packages/torch/lib/lib{caffe2_nvrtc,torch_cuda_linalg}.so
  '';
}
