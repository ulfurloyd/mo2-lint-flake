self:
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
  imports = [
    (lib.mkRemovedOptionModule
      [ "programs" "mo2-lint" "nxmHandler" "launcherSerevice" ]
      "steam-run-free is now bundled; use `package = pkgs.mo2-lint.override { withSteamRun = false; }` to opt out."
    )
  ];

  options.programs.mo2-lint = {
    enable = mkEnableOption "MO2-LINT";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalMD "`mo2-lint.packages.<system>.default` from this flake";
      description = '';
        The MO2-LINT package to install. To build against your own nixpkgs, apply
        `overlays.default` and set this to `pkgs.mo2-lint`.
      '';
    };

    nxmHandler = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install the NXM handler and register it for nxm:// links declaratively.";
      };
    };

    settings = {
      installer = {
        log_level = mkOption {
          type = types.enum [ "debug" "info" "trace" ];
          default = "info";
          description = "Default log level when `--log-level` isn't provided.";
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

  config = mkIf cfg.enable (lib.mkMerge [
    {
      home.packages = [ cfg.package ];

      xdg.configFile."mo2-lint/settings.toml".source = tomlFormat.generate "mo2-lint-settings.toml" {
        inherit (cfg.settings) installer instance;
      };
    }

    (mkIf cfg.nxmHandler.enable {
      xdg.dataFile."mo2-lint/nxm-handler" = {
        source = "${cfg.package}/lib/mo2-lint/dist/nxm-handler";
        force = true;
      };
      xdg.dataFile."applications/mo2lint_nxm-handler.desktop" = {
        source = "${cfg.package}/lib/mo2-lint/configs/nxm-handler.desktop";
        force = true;
      };

      xdg.mimeApps = {
        enable = lib.mkDefault true;
        defaultApplications."x-scheme-handler/nxm" = [ "mo2lint_nxm-handler.desktop" ];
      };

      home.activation.mo2LintDesktopDatabase = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${pkgs.desktop-file-utils}/bin/update-desktop-database ${config.xdg.dataHome}/applications
      '';
    })
  ]);
}
