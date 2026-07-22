{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  enabled-wordpress-compose = filterAttrs (_: cfg: cfg.enable) config.myOpt.wordpress-compose;
in {
  options.myLib = {
    wpFetch = mkOption {
      readOnly = true;
      type = types.functionTo (types.functionTo (types.package));
      default = type: {
        name,
        version,
        hash,
      }: (pkgs.stdenv.mkDerivation rec {
        inherit name version hash;
        src = pkgs.fetchzip {
          inherit name version hash;
          url = "https://downloads.wordpress.org/${type}/${name}.${version}.zip";
        };
        installPhase = "mkdir -p $out; cp -R * $out/";
      });
    };
    wpPluginFetch = mkOption {
      readOnly = true;
      type = types.functionTo (types.package);
      default = config.myLib.wpFetch "plugin";
    };
    wpThemeFetch = mkOption {
      readOnly = true;
      type = types.functionTo (types.package);
      default = config.myLib.wpFetch "theme";
    };
  };

  options.myOpt.wordpress-compose = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: (let
      cfg = innerArgs.config;
      containerCfg = config.containers.${cfg.container.name}.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        proxy-compose = mkOption {
          type = types.anything;
          default = {};
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "container@${cfg.container.name}";
          readOnly = true;
        };
        origin.socket-address = mkOption {
          type = types.singleLineStr;
          default = "/run/${cfg.container.name}${cfg.container.origin.socket-address}";
          readOnly = true;
        };
        container = {
          name = mkOption {
            type = types.singleLineStr;
            default = name;
          };
          origin.socket-address = mkOption {
            type = types.singleLineStr;
            default = containerCfg.services.phpfpm.pools."wordpress-${cfg.proxy-compose.hostName}".socket;
            readOnly = true;
          };
        };
        plausible-domain = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        wordpress = {
          package = mkOption {
            type = types.package;
          };
          stateDir = mkOption {
            type = types.singleLineStr;
          };
          uploadsDir = mkOption {
            type = types.singleLineStr;
            default = "${cfg.wordpress.stateDir}/${cfg.proxy-compose.hostName}/uploads";
            readOnly = true;
          };
          fontsDir = mkOption {
            type = types.singleLineStr;
            default = "${cfg.wordpress.stateDir}/${cfg.proxy-compose.hostName}/fonts";
            readOnly = true;
          };
          muPlugins = mkOption {
            type = with types; (attrsOf path);
            default = {};
            apply = user: (
              (optionalAttrs (cfg.plausible-domain != null) {
                "plausible.php" = pkgs.writeText "${name}-plausible.php" ''
                  <?php
                  add_action("wp_head", function () {
                      ?>
                      <script defer data-domain="${cfg.proxy-compose.hostName}" src="https://${cfg.plausible-domain}/js/script.js"></script>
                      <?php
                  });
                '';
              })
              // user
            );
          };
          themes = mkOption {
            type = with types; (attrsOf path);
          };
          plugins = mkOption {
            type = with types; (attrsOf path);
            default = {};
          };
          extraConfig = mkOption {
            type = types.lines;
            default = '''';
          };
          extra-installPhase = mkOption {
            type = types.lines;
            default = '''';
          };
          symlinks = mkOption {
            type = with types; listOf singleLineStr;
            default = [];
          };
          settings = mkOption {
            type = with types; attrsOf anything;
            default = {};
          };
        };
        mariadb = {
          package = mkOption {
            type = types.package;
          };
          stateDir = mkOption {
            type = types.singleLineStr;
          };
        };
        php = {
          package = mkOption {
            type = types.package;
            default = pkgs.php;
          };
          extensions = mkOption {
            type = with types; functionTo (listOf package);
            default = {...}: [];
          };
        };
        max-age = mkOption {
          type = types.int;
          default = 300;
        };
      };
    })));
  };

  config.myOpt.proxy-compose = mkMerge (mapAttrsToList (
      _: cfg: (let
        containerCfg = config.containers.${cfg.container.name}.config;
      in {
        ${cfg.serviceName} = mkMerge [
          cfg.proxy-compose
          {
            localMode.port = mkDefault 15653;
            sleep-on-idle.endpoints.default = {
              inherit (cfg) origin;
            };
            caddy = {
              add-handle-reverse-proxy = false;
              # @wpCache {
              #   not header_regexp Cookie "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_logged_in"
              #   not path_regexp "(/wp-admin/|/xmlrpc.php|/wp-(app|cron|login|register|mail).php|wp-.*.php|/feed/|index.php|wp-comments-popup.php|wp-links-opml.php|wp-locations.php|sitemap(index)?.xml|[a-z0-9-]+-sitemap([0-9]+)?.xml)"
              #   not method POST
              #   not expression {query} != ""
              #   file {
              #     root ${cfg.wordpress.stateDir}/${cfg.proxy-compose.hostName}/cache-enabler/${cfg.proxy-compose.hostName}
              #     try_files {path}index.html
              #   }
              # }
              # handle @wpCache {
              #   root * ${cfg.wordpress.stateDir}/${cfg.proxy-compose.hostName}/cache-enabler/${cfg.proxy-compose.hostName}
              #   file_server {
              #     precompressed
              #   }
              #   rewrite * {file_match.relative}
              #   header +Cache-Control "public, max-age=${toString cfg.max-age}, stale-while-revalidate=31536000, stale-if-error=31536000"
              # }

              # @wpStaticFiles {
              #   path_regexp path ^/wp-content/(?:uploads|fonts)/
              #   file {
              #     root ${containerCfg.services.wordpress.sites.${cfg.proxy-compose.hostName}.finalPackage}/share/wordpress
              #     try_files {path}
              #   }
              # }
              # handle @wpStaticFiles {
              #   root * ${containerCfg.services.wordpress.sites.${cfg.proxy-compose.hostName}.finalPackage}/share/wordpress
              #   file_server
              #   header +Cache-Control "public, max-age=${toString cfg.max-age}, stale-while-revalidate=31536000, stale-if-error=31536000"
              # }
              extraConfig = ''

                handle {
                  root * ${containerCfg.services.wordpress.sites.${cfg.proxy-compose.hostName}.finalPackage}/share/wordpress
                  file_server

                  php_fastcgi ${config.myOpt.proxy-compose.${cfg.serviceName}.default-caddy-origin-socket-address}

                  @uploads-php {
                    path_regexp path /uploads/(?:.*)\.php
                  }
                  rewrite @uploads-php /

                }
              '';
            };
          }
        ];
      })
    )
    enabled-wordpress-compose);

  config.containers = mkMerge (mapAttrsToList (
      _: cfg: (let
        containerCfg = config.containers.${cfg.container.name}.config;
      in {
        ${cfg.container.name} = {
          bindMounts = {
            "/var/lib/wordpress" = {
              hostPath = cfg.wordpress.stateDir;
              isReadOnly = false;
            };
            ${cfg.wordpress.stateDir} = {
              hostPath = cfg.wordpress.stateDir;
              isReadOnly = false;
            };
            ${containerCfg.services.mysql.dataDir} = {
              hostPath = cfg.mariadb.stateDir;
              isReadOnly = false;
            };
            ${builtins.dirOf cfg.container.origin.socket-address} = {
              hostPath = builtins.dirOf cfg.origin.socket-address;
              isReadOnly = false;
            };
          };
          config.imports = [
            ({lib, ...}:
              with lib; {
                services.caddy.enable = mkForce false;
                users.users.caddy = {
                  uid = config.ids.uids.caddy;
                  group = "caddy";
                };
                users.groups.caddy.gid = config.ids.gids.caddy;

                services.phpfpm.pools."wordpress-${cfg.proxy-compose.hostName}".phpPackage = cfg.php.package.buildEnv {
                  extensions = {
                    enabled,
                    all,
                  } @ ext-inputs:
                    enabled
                    ++ (with all; [
                      imagick
                      opcache
                      apcu
                    ])
                    ++ (cfg.php.extensions ext-inputs);
                };

                systemd.tmpfiles.rules =
                  map (
                    wp_path: "d '${cfg.wordpress.stateDir}/${cfg.proxy-compose.hostName}${wp_path}' 0750 wordpress caddy - -"
                  )
                  cfg.wordpress.symlinks;

                services.wordpress = {
                  webserver = "caddy";
                  sites.${cfg.proxy-compose.hostName} = {
                    inherit (cfg.wordpress) themes plugins fontsDir uploadsDir;
                    extraConfig =
                      ''
                        // Detect HTTPS from the Cloudflare Tunnel → Caddy chain
                        if (
                          (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') ||
                          (isset($_SERVER['HTTP_CF_VISITOR']) && strpos($_SERVER['HTTP_CF_VISITOR'], 'https') !== false)
                        ) {
                          $_SERVER['HTTPS'] = 'on';
                        }
                      ''
                      + cfg.wordpress.extraConfig;
                    settings = mkMerge [
                      {
                        WP_CACHE = mkDefault true;
                        FORCE_SSL_ADMIN = true;
                        WP_HOME = "https://${cfg.proxy-compose.hostName}";
                        WP_SITEURL = "https://${cfg.proxy-compose.hostName}";
                      }
                      cfg.wordpress.settings
                    ];
                    package = pkgs.stdenv.mkDerivation rec {
                      pname = "wordpress-${cfg.container.name}";
                      version = src.version;
                      src = cfg.wordpress.package;

                      installPhase =
                        ''
                          mkdir -p $out
                          cp -r * $out/

                          mkdir -p $out/share/wordpress/wp-content/mu-plugins
                          ${concatStringsSep "\n" (
                            mapAttrsToList (
                              name: plugin: "cp -r ${plugin} $out/share/wordpress/wp-content/mu-plugins/${name}"
                            )
                            cfg.wordpress.muPlugins
                          )}

                          ${concatStringsSep "" (
                            map (
                              wp_path: ''
                                mkdir -p $out/share/wordpress${builtins.dirOf wp_path}
                                ln -s ${cfg.wordpress.stateDir}/${cfg.proxy-compose.hostName}${wp_path} $out/share/wordpress${wp_path}
                              ''
                            )
                            cfg.wordpress.symlinks
                          )}
                        ''
                        + cfg.wordpress.extra-installPhase;
                    };
                  };
                };
                services.mysql = {
                  inherit (cfg.mariadb) package;
                };
              })
          ];
        };
      })
    )
    enabled-wordpress-compose);

  config.systemd.tmpfiles.rules = flatten (
    mapAttrsToList (_: cfg: ([
        "d '${cfg.wordpress.fontsDir}' - - - - -"
        "d '${cfg.wordpress.uploadsDir}' - - - - -"
        "d '${cfg.mariadb.stateDir}' - - - - -"
        "d '${builtins.dirOf cfg.origin.socket-address}' - - - - -"
      ]
      ++ (map (
          wp_path: "d '${cfg.wordpress.stateDir}/${cfg.proxy-compose.hostName}${wp_path}' - - - - -"
        )
        cfg.wordpress.symlinks)))
    enabled-wordpress-compose
  );
}
