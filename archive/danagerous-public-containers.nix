{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.myOpt.dangerous-public-containers;

  containerOpts = {
    name,
    config,
    ...
  }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = false;
        example = true;
      };

      sops-totp-key = mkOption {
        type = types.str;
        default = "${name}/totp-secret";
        example = "dev-sandbox/totp-secret";
      };

      sharedSocketDir = mkOption {
        type = types.str;
        default = "/run/caddy/sockets/${name}";
        example = "/run/caddy/sockets/dev-sandbox";
      };

      safeDataHostPath = mkOption {
        type = types.str;
        example = "/var/lib/my-safe-projects/app1";
      };

      safeDataContainerPath = mkOption {
        type = types.str;
        default = "/home/ai-assistant/project";
        example = "/home/ai-assistant/project";
      };

      sshAuthorizedKeysFile = mkOption {
        type = types.path;
        example = "/var/lib/dangerous-container/keys/authorized_keys";
      };

      totpInterval = mkOption {
        type = types.int;
        default = 3600;
        example = 3600;
      };

      totpCaddyPort = mkOption {
        type = types.port;
        default = 9999;
        example = 9999;
      };

      caddyFileServerRoot = mkOption {
        type = types.str;
        default = "/run/caddy/file-server/${name}";
        example = "/run/caddy/file-server/dev-sandbox";
      };
    };
  };
in {
  options.myOpt.dangerous-public-containers = mkOption {
    type = types.attrsOf (types.submodule containerOpts);
    default = {};
  };

  # config = mkMerge (mapAttrsToList (name: containerCfg:
  #   mkIf containerCfg.enable {
  #     systemd.tmpfiles.rules = [
  #       "d ${containerCfg.sharedSocketDir} 0770 caddy caddy - -"
  #       "d ${containerCfg.caddyFileServerRoot} 0700 caddy caddy - -"
  #     ];

  #     system.activationScripts."rotate-ssh-key-${name}" = {
  #       supportsDryRun = true;
  #       text = ''
  #         mkdir -p ${containerCfg.caddyFileServerRoot}
  #         chmod 700 ${containerCfg.caddyFileServerRoot}
  #         rm -f ${containerCfg.caddyFileServerRoot}/id_ed25519*
  #         ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${containerCfg.caddyFileServerRoot}/id_ed25519 -C "temp-key-${name}"
  #         chown -R caddy:caddy ${containerCfg.caddyFileServerRoot}
  #       '';
  #     };

  #     services.caddy = {
  #       enable = true;
  #       extraConfig = ''
  #         route /ssh-key {
  #           forward_auth 127.0.0.1:${toString containerCfg.totpCaddyPort} {
  #             uri /auth
  #             copy_headers Authorization
  #           }

  #           root * ${containerCfg.caddyFileServerRoot}
  #           file_server {
  #             hide id_ed25519
  #           }
  #         }
  #       '';
  #     };

  #     systemd.services."totp-validator-${name}" = {
  #       after = ["network.target"];
  #       wantedBy = ["multi-user.target"];
  #       path = [pkgs.oathtool pkgs.netcat-gnu];
  #       script = ''
  #         SECRET_FILE="${config.sops.secrets."${containerCfg.sops-totp-key}".path}"
  #         PORT="${toString containerCfg.totpCaddyPort}"
  #         INTERVAL="${toString containerCfg.totpInterval}"

  #         handler() {
  #           read -r req
  #           auth_val=""
  #           while read -r line; do
  #             line=$(echo "$line" | tr -d '\r')
  #             [ -z "$line" ] && break
  #             if echo "$line" | grep -qi "^Authorization:"; then
  #               auth_val=$(echo "$line" | cut -d' ' -f3)
  #             fi
  #           done

  #           if [ -z "$auth_val" ]; then
  #             printf "HTTP/1.1 401 Unauthorized\r\nContent-Length: 13\r\n\r\nMissing Token"
  #             return
  #           fi

  #           SECRET=$(cat "$SECRET_FILE" | tr -d ' \n\r')
  #           if oathtool --totp -s "$INTERVAL" --base32 "$SECRET" "$auth_val" >/dev/null 2>&1; then
  #             printf "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
  #           else
  #             printf "HTTP/1.1 401 Unauthorized\r\nContent-Length: 11\r\n\r\nInvalid OTP"
  #           fi
  #         }

  #         export -f handler
  #         export SECRET_FILE PORT INTERVAL

  #         nc -lkp "$PORT" -e bash -c "handler"
  #       '';
  #     };

  #     containers."${name}" = {
  #       autoStart = false;
  #       privateNetwork = true;
  #       ephemeral = true;

  #       bindMounts = {
  #         "/run/shared-sockets" = {
  #           hostPath = containerCfg.sharedSocketDir;
  #           isReadOnly = false;
  #         };
  #         "${containerCfg.safeDataContainerPath}" = {
  #           hostPath = containerCfg.safeDataHostPath;
  #           isReadOnly = false;
  #         };
  #         "/etc/ssh/authorized_keys" = {
  #           hostPath = containerCfg.sshAuthorizedKeysFile;
  #           isReadOnly = true;
  #         };
  #         "/run/secrets/totp-secret" = {
  #           hostPath = config.sops.secrets."${containerCfg.sops-totp-key}".path;
  #           isReadOnly = true;
  #         };
  #       };

  #       config = {
  #         config,
  #         pkgs,
  #         ...
  #       }: {
  #         services.openssh = {
  #           enable = true;
  #           openFilesLimit = 1024;
  #           settings = {
  #             PasswordAuthentication = false;
  #             KbdInteractiveAuthentication = true;
  #             ClientAliveInterval = 300;
  #             ClientAliveCountMax = 2;
  #           };
  #           extraConfig = ''
  #             ListenAddress none
  #           '';
  #         };

  #         systemd.sockets.sshd = {
  #           wantedBy = ["sockets.target"];
  #           listenStreams = ["/run/shared-sockets/container-ssh.sock"];
  #         };

  #         security.pam.services.sshd = {
  #           text = ''
  #             auth required pam_unix.so try_first_pass
  #             auth required pam_exec.so expose_authtok ${pkgs.bash}/bin/bash -c '
  #               read -r otp_code
  #               SECRET=$(${pkgs.coreutils}/bin/cat /run/secrets/totp-secret | ${pkgs.gnused}/bin/sed "s/ //g")
  #               if ${pkgs.oathtool}/bin/oathtool --totp -s ${toString containerCfg.totpInterval} --base32 "$SECRET" "$otp_code" >/dev/null 2>&1; then
  #                 exit 0
  #               else
  #                 exit 1
  #               fi
  #             '
  #           '';
  #         };

  #         users.users.ai-assistant = {
  #           isNormalUser = true;
  #           home = "/home/ai-assistant";
  #           createHome = true;
  #           openssh.authorizedKeys.keyFiles = ["/etc/ssh/authorized_keys"];
  #         };
  #       };
  #     };
  #   })
  # cfg);
}
