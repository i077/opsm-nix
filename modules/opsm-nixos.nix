{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  inherit (config.users) users;
  cfg = config.opsm;

  secretDir = "/run/secrets";

  secretType = types.submodule ({config, ...}: {
    options = {
      secretRef = mkOption {
        type = types.str;
        description = ''Reference to the secret in 1Password. Should be in the form "op://vault/entry/field".'';
        example = "op://vault/entry/field";
      };

      user = mkOption {
        type = types.str;
        description = "Owner of the installed file.";
        default = "0";
      };

      group = mkOption {
        type = types.str;
        description = "Group owner of the installed file.";
        default = users.${config.owner}.group or "0";
      };

      mode = mkOption {
        type = types.str;
        description = "Access permissions of the installed file, in a form understood by chmod.";
        default = "0400";
      };

      # TODO not sure this is necessary
      # requiringServices = mkOption { 
      #   type = with types; listOf str;
      #   description = ''List of systemd units that should require this secret to be installed before they should start. This will set the listed units' `Requires` and `After` to the service corresponding to this secret.'';
      #   default = [];
      # };
    };
  });
in {
  options.opsm = {
    enable = mkEnableOption "1Password secrets management";

    serviceAccountTokenPath = mkOption {
      type = types.str;
      default = "/etc/opsm-token";
      description = ''
        Path to the token for the 1Password Service Account. This should be a string literal,
        not a path, so as to avoid copying the token to the world-readable Nix store.
        This file should only be readable by root:root, with mode 0400.
      '';
    };

    refreshInterval = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        Interval, in seconds, at which all secrets should be re-read from 1Password.
        If null, secrets will not be refreshed except for when the backing service is restarted.
      '';
    };

    secrets = mkOption {
      type = types.attrsOf secretType;
      default = {};
      description = ''
        Attribute set of secrets to be deployed to the machine. These will be read from 1Password
        using the CLI and the service account token located in opsm.serviceAccountTokenPath.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # During activation, ensure a ramfs exists at the destination directory
    system.activationScripts.opsm-secrets-init = {
      text = ''
        mkdir -p ${secretDir}
        chmod 0751 ${secretDir}
        if ! grep -q "${secretDir} ramfs" /proc/mounts; then
          mount -t ramfs none ${secretDir} -o nodev,nosuid,mode=0751
        fi
      '';
    };

    # Create a target to group all secret services
    systemd.targets.opsm-secrets = {};

    # Create services for each secret and a service that resolves when all keys are deployed
    systemd.services = lib.mapAttrs' (n: v: lib.nameValuePair "opsm-secret-${n}" {
      enable = true;

      serviceConfig.TimeoutStartSec = "5m";
      serviceConfig.Restart = "always";
      serviceConfig.RestartSec = "1s";

      path = [ pkgs._1password ];

      environment.OP_SERVICE_ACCOUNT_TOKEN = "$(cat ${cfg.serviceAccountTokenPath})";

      # We need Internet access to read from 1Password
      wants = ["network-online.target"];
      after = ["network-online.target"];

      wantedBy = ["opsm-secrets.target"];

      preStart = ''
        # Ensure connectivity to 1Password server
        op whoami
      '';
    });
  };
}
