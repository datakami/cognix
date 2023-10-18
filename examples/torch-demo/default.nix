{
  cog.build.python_snapshot_date = "2023-10-05";
  python-env.pip.drvs.torch.mkDerivation.postInstall = ''
    rm $out/lib/python*/site-packages/torch/lib/lib{caffe2_nvrtc,torch_cuda_linalg}.so
  '';
}
