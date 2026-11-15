{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.vigil;
in
{
  options.services.vigil = {
    enable = lib.mkEnableOption "Vigil - computer monitoring and control software";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.vigil-unwrapped;
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/vigil";
    };

    publicKey = lib.mkOption {
      description = "Named public key stored under /etc/vigil/keys/public/<name>/key";

      type = lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "test";
          };

          value = lib.mkOption {
            type = lib.types.lines;
            default = ''
              -----BEGIN PUBLIC KEY-----
              ...
              -----END PUBLIC KEY-----
            '';
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.vigil = { };

    environment.systemPackages = [ cfg.package ];

    environment.etc."vigil/keys/public/${cfg.publicKey.name}/key".text = cfg.publicKey.value;

    systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0750 root vigil - -" ];

    systemd.services.vigil-service = {
      description = "Vigil Service";

      documentation = [ "man:vigil-service(1)" ];

      after = [
        "network-online.target"
        "dbus.service"
        "systemd-logind.service"
      ];

      wants = [
        "network-online.target"
      ];

      requires = [
        "dbus.service"
        "systemd-logind.service"
      ];

      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/vigil-service";
        Type = "simple";
        Restart = "always";
        RestartSec = 0;
      };

      startLimitIntervalSec = 60;
      startLimitBurst = 10;
    };

    networking.firewall = {
      allowedTCPPorts = [
        11100
        11200
        11300
      ];
      allowedUDPPorts = [
        11100
        11200
        11300
      ];
    };

    security.wrappers.vigil-auth-helper = {
      source = "${cfg.package}/bin/vigil-auth-helper";
      owner = "root";
      group = "root";
      setuid = true;
    };
  };
}
