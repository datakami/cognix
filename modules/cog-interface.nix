{
  config, lib, dream2nix, packageSets, ...
}:
let
  cfg = config.cog;
in
{
  options.cog = with lib; {
    name = mkOption {
      type = types.str;
    };
    build = {
      gpu = mkEnableOption "GPU support";
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
    };
    predict = mkOption {
      type = types.str;
      default = "predict.py:Predictor";
    };
  };
  options.cognix.systemPackages = with lib; mkOption {
    default = {};
    type = types.attrsOf types.package;
  };
  options.python-env = with lib; mkOption {
    type = types.submoduleWith {
      modules = [ dream2nix.modules.dream2nix.core ];
      specialArgs = { inherit packageSets dream2nix; };
    };
  };
}
