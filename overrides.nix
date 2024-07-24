{
  ## GPU overrides
  torch = { config, ... }: {
    # make it so torch + cuda libs can find the libs from nvidia-docker
    # see https://github.com/nix-community/dream2nix/issues/698
    env.appendRunpaths = [ "/usr/lib64" "$ORIGIN" ];

    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/python-modules/torch/fix-cmake-cuda-toolkit.patch
    mkDerivation.postInstall = ''
      rm $out/${config.deps.python.sitePackages}/torch/share/cmake/Caffe2/FindCUDAToolkit.cmake
    '';
    # seems to be a bug in the torch-cu117 package
    env.autoPatchelfIgnoreMissingDeps = [ "libnvToolsExt.so.1" ];
  };
  nvidia-cublas-cu11.env.appendRunpaths = [ "/usr/lib64" "$ORIGIN" ];
  nvidia-cudnn-cu11.env.appendRunpaths = [ "/usr/lib64" "$ORIGIN" ];
  nvidia-curand-cu11.env.appendRunpaths = [ "/usr/lib64" "$ORIGIN" ];

  nvidia-cublas-cu12.env.appendRunpaths = [ "/usr/lib64" "$ORIGIN" ];
  nvidia-cudnn-cu12.env.appendRunpaths = [ "/usr/lib64" "$ORIGIN" ];
  nvidia-curand-cu12.env.appendRunpaths = [ "/usr/lib64" "$ORIGIN" ];

  vllm.env.autoPatchelfIgnoreMissingDeps = [ "libcuda.so.1" ];
  vllm.env.appendRunpaths = [ "/run/opengl-driver/lib" "/usr/lib64" "$ORIGIN" ];

  mpi4py = { config, lib, ... }: {
    mkDerivation.buildInputs = [ config.deps.openmpi ];
    mkDerivation.nativeBuildInputs = [ config.deps.openmpi ];
    deps = { nixpkgs, ... }: {
      openmpi = lib.mkDefault nixpkgs.openmpi;
    };
  };

  numba = { config, lib, ... }: {
    mkDerivation.buildInputs = [ config.deps.tbb ];
    deps = { nixpkgs, ... }: {
      # TODO: should this have hwloc (and with enableCUDA)?
      tbb = lib.mkDefault nixpkgs.tbb_2021_11;
    };
  };
}
