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
      };
      system_packages = mkOption {
        # strings not supported yet
        type = types.listOf (types.oneOf [types.path types.str]);
        default = [];
      };
      python_packages = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      python_snapshot_date = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      python_extra_index_urls = mkOption {
        type = types.listOf types.str;
        default = [];
        apply = lib.unique;
      };
      cog_version = mkOption {
        type = types.str;
        default = "0.8.6";
      };
    };
    predict = mkOption {
      type = types.str;
      default = "predict.py:Predictor";
    };
    train = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "train.py:train";
    };
  };
  options.cognix = with lib; {
    systemPackages = mkOption {
      default = {};
      type = types.attrsOf types.package;
    };
    sourceIgnores = mkOption {
      type = types.lines;
      default = "";
      example = ''
        /models/*
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
  };
  options.python-env = with lib; mkOption {
    type = types.submoduleWith {
      modules = [ dream2nix.modules.dream2nix.core ];
      specialArgs = { inherit packageSets dream2nix; };
    };
  };
}
