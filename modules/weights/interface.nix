{ lib, ... }:
{
  options.cog.weights = with lib; mkOption {
    type = types.listOf (types.submodule {
      options = {
        src = mkOption {
          type = types.str;
          example = "thenlper/gte-small";
        };
        rev = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "git revision to use";
        };
        ref = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "branch name to fetch";
        };
        build_include = mkOption {
          type = types.listOf types.str;
          default = [];
          description = ''
            List of file globs to download at image build time
          '';
          example = [ "model.safetensors" ];
        };
        download_include = mkOption {
          type = types.listOf types.str;
          default = [];
          description = ''
            List of file globs to download at image run time
          '';
        };
      };
    });
    default = [];
  };
}
