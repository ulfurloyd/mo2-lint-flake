{ package }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.programs.mo2-lint;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.programs.mo2-lint = {
    enable = mkEnableOption "MO2-LINT";

    package = mkOption {
      type = types.package;
      default = package;
      defaultText = lib.literalExpression "mo2-lint package from the flake";
      description = "The MO2-LINT package to install";
    };

    settings = {
      installer = {
        log_level = mkOption {
          type = types.str;
          default = "info";
          description = "Default log level when `--log-level` isn't provided. `INFO` if unset.";
        };

        check_updates = mkOption {
          type = types.bool;
          default = true;
          description = "Set `false` to skip the startup GitHub version check.";
        };

        refresh_configs = mkOption {
          type = types.bool;
          default = true;
          description = "Set `false` to skip pulling remote config files on startup.";
        };
      };

      instance = {
        launcher = mkOption {
          type = types.str;
          default = "";
          description = "Default launcher when one isn’t provided with `--launcher`. Leave blank to auto-detect. If the selected game isn’t available on the selected launcher, MO2-LINT falls back to auto-detection.";
        };

        theme = mkOption {
          type = types.str;
          default = "";
          description = "Default theme when one isn't provided with `--theme`. Leave blank for no theme.";
        };

        plugins = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Default plugins for new instances when not provided with `--plugin`. Leave blank for none.";
        };

        folders = {
          root_folder = mkOption {
            type = types.str;
            default = "~/Games/mo2-lint";
            description = "Base directory for new instances.";
          };

          folder_name = mkOption {
            type = types.str;
            default = "mo2-{game}-{launcher}";
            description = "Instance folder name template. Supports `{game}` and `{launcher}` placeholders.";
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."mo2-lint/settings.toml".source = tomlFormat.generate "mo2-lint-settings.toml" {
      inherit (cfg.settings) installer instance;
    };
  };
}
