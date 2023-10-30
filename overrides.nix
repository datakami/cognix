{
  ## GPU overrides
  # make it so torch + cuda libs can find the libs from nvidia-docker
  # see https://github.com/nix-community/dream2nix/issues/698
  torch.env.appendRunpaths = [ "/usr/lib64" "$ORIGIN" ];
  # seems to be a bug in the torch-cu117 package
  torch.env.autoPatchelfIgnoreMissingDeps = [ "libnvToolsExt.so.1" ];
  nvidia-cublas-cu11.env.appendRunpaths = [ "/usr/lib64" "$ORIGIN" ];
  nvidia-cudnn-cu11.env.appendRunpaths = [ "/usr/lib64" "$ORIGIN" ];
  nvidia-curand-cu11.env.appendRunpaths = [ "/usr/lib64" "$ORIGIN" ];
}
