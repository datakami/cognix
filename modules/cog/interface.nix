{
  config, lib, dream2nix, packageSets, ...
}:
let
  cfg = config.cog;
in
{
  options.cog = with lib; {
    build = {
      gpu = mkEnableOption "GPU support";
      cuda = mkOption {
        type = types.enum [ null "11.0" "11.1" "11.3" "11.5" "11.6" "11.7" "11.8" "12.1" ];
      };
      python_version = mkOption {
        type = types.enum [ "3.8" "3.9" "3.10" "3.11" "3.12" ];
        example = "3.11";
        description = ''
          The minor version of Python to use.
        '';
      };
      system_packages = mkOption {
        # strings not supported yet
        type = types.listOf (types.oneOf [types.path types.str]);
        default = [];
        example = [ "pget" "openmpi" ];
        description = ''
          A list of Nix packages to install. A full list of the available packages can be found at
          https://search.nixos.org/packages .
          Additionally, [pget](https://github.com/replicate/pget) is also available here, along with any other
          packages custom added to `cognix.systemPackages`.
        '';
      };
      python_packages = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "torch" ];
        description = ''
          A list of Python packages to install, from all of the specified repositories in
          `python_extra_index_urls`.
        '';
      };
      python_snapshot_date = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          When writing the lock file, ignore packages published to repositories after this date.
        '';
      };
      python_extra_index_urls = mkOption {
        type = types.listOf types.str;
        default = [];
        apply = lib.unique;
        description = ''
          Extra python repositories to use.
        '';
      };
      cog_version = mkOption {
        type = types.str;
        default = "0.9.4";
        description = "The cog-python version to add to the image.";
      };
    };
    predict = mkOption {
      type = types.str;
      default = "predict.py:Predictor";
      description = ''
        The pointer to the Predictor object in your code, which defines how predictions are run on your model.
      '';
    };
    train = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "train.py:train";
      description = ''
        The pointer to the train function in your code, which defines how your model can be trained.
      '';
    };
    concurrency = {
      max = mkOption {
        type = types.int;
        default = 1;
        description = "Allowed concurrency";
      };
    };
  };
  options.cognix = with lib; {
    systemPackages = mkOption {
      default = {};
      type = types.attrsOf types.package;
      description = ''
        Packages to make available for `cog.build.system_packages`.
      '';
    };
    sourceIgnores = mkOption {
      type = types.lines;
      default = "";
      example = ''
        /models/*
      '';
      description = ''
        gitignore syntax, don't copy these files to the /src package in the image
      '';
    };
    rootPath = mkOption {
      type = types.str;
      description = "Path containing cog.yaml, predict.py, .dockerignore";
    };
    postCopyCommands = mkOption {
      type = types.lines;
      default = "";
      example = ''
        touch $out/src/.env
      '';
      description = "Commands to run after gathering all the files for the container /src dir";
    };
    addCudaLibraryPath = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to add the CUDA paths from docker-nvidia to LD_LIBRARY_PATH.
        Disable to sanity check your dependencies.
      '';
    };
    environment = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = ''
        Set these environment variables in the image.
      '';
    };
    openapi_schema = mkOption {
      type = types.path;
      description = ''
        Specify a path to openapi.json added to the image. Defaults to the spec generated using python -m cog.command.openapi_schema.
      '';
    };
    python_root_packages = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = null;
      example = [ "nvidia-pytriton" "transformers" "tokenizers" ];
      description = ''
        Only include the dependencies of these python packages in the final image. This allows you to build multiple images with the same `lock.json`, containing different subsets of python packages.
      '';
    };
    fake_pip = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install a fake pip wrapper that does nothing.

        This is useful because replicate calls `pip install cog==...` before starting your image, which you may not want when using a patched version of cog's python library.
      '';
    };
  };
  options.python-env = with lib; mkOption {
    description = ''
      Sub-module containing the python environment that's used in the image.
    '';
    type = types.submoduleWith {
      modules = [ dream2nix.modules.dream2nix.core ];
      specialArgs = { inherit packageSets dream2nix; };
    };
  };
}
