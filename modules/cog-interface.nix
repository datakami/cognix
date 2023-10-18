{
  config, lib, dream2nix, packageSets, ...
}:
let
  cfg = config.cog;
in
{
  options.cog = with lib; {
    build.gpu = mkEnableOption "GPU support";
    name = mkOption {
      type = types.str;
    };
    python_version = mkOption {
      # not supported yet
      type = types.enum [ "3.10" ];
    };
    system_packages = mkOption {
      # strings not supported yet
      type = types.listOf types.path;
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
    predict = mkOption {
      type = types.path;
    };
  };
  options.python-env = with lib; mkOption {
    type = types.submoduleWith {
      modules = [ dream2nix.modules.dream2nix.core ];
      specialArgs = { inherit packageSets dream2nix; };
    };
  };
  config = {
    assertions = [
      {
        assertion = cfg.python_version == "3.10";
        message = "python_versions other than 3.10 not supported yet";
      }
    ];
  };
}
