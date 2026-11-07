{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  outerCfg = config;
  enabled = filterAttrs (_: cfg: cfg.enable) outerCfg.myOpt.make-frappe-bench;

  toSliceUnit = p:
    if p == null
    then null
    else if hasSuffix ".slice" p
    then p
    else "${p}.slice";

  mkEnabledAppsList = cfg: let
    enabledApps = filterAttrs (_: a: a.enable) cfg.apps;
    withNames =
      mapAttrsToList (appName: a: {
        inherit appName;
        inherit (a) url branch order;
      })
      enabledApps;
  in
    sort (
      a: b:
        if a.order != b.order
        then a.order < b.order
        else a.appName < b.appName
    )
    withNames;

  mkAppsJson = name: cfg: let
    appsList = map (a: {inherit (a) url branch;}) (mkEnabledAppsList cfg);
  in
    pkgs.writeText "apps-${name}.json" (builtins.toJSON appsList);

  bench-init-script = pkgs.writeScript "make-frappe-bench-init.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail

    : "''${FRAPPE_URL:?FRAPPE_URL is required}"
    : "''${FRAPPE_BRANCH:?FRAPPE_BRANCH is required}"

    app_args=()
    if [[ -s /opt/frappe/apps.json ]] && [[ "$(cat /opt/frappe/apps.json)" != "[]" ]]; then
      app_args=(--apps_path=/opt/frappe/apps.json)
    fi

    bench init --ignore-exist \
      "''${app_args[@]}" \
      --frappe-path "$FRAPPE_URL" \
      --frappe-branch "$FRAPPE_BRANCH" \
      --no-procfile \
      --no-backups \
      --skip-redis-config-generation \
      /home/frappe/frappe-bench

    cd /home/frappe/frappe-bench
    echo "{}" > sites/common_site_config.json
    find apps -mindepth 1 -path "*/.git" -prune -exec rm -rf {} +
    rm -rf /home/frappe/frappe-bench/logs
    mkdir -p /home/frappe/frappe-bench/logs
    chmod -R g=u,o-w /home/frappe/frappe-bench
    chmod 0770 /home/frappe/frappe-bench
  '';

  make-frappe-bench-readonly = getExe (pkgs.writeShellApplication {
    name = "make-frappe-bench-readonly";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      : "''${BENCH_DIR:?BENCH_DIR is required}"

      BENCH_DIR="''${BENCH_DIR%/}"
      if [[ -d "$BENCH_DIR/apps/frappe" ]]; then
        echo "WARNING: readOnlyMode is enabled; skipping frappe-bench rebuild at ''${BENCH_DIR}." >&2
        echo "Changes to apps/branches will not take effect until readOnlyMode is disabled." >&2
        exit 0
      fi

      echo "ERROR: readOnlyMode is enabled but no valid frappe-bench exists at ''${BENCH_DIR}." >&2
      echo "A read-only deployment needs an existing bench; disable readOnlyMode" >&2
      echo "for the first deployment, then re-enable it." >&2
      exit 1
    '';
  });

  make-frappe-bench = getExe (pkgs.writeShellApplication {
    name = "make-frappe-bench";
    runtimeInputs = [
      outerCfg.virtualisation.podman.package
      pkgs.coreutils
    ];
    text = ''
      : "''${BENCH_DIR:?BENCH_DIR is required}"
      : "''${APPS_JSON:?APPS_JSON is required}"
      : "''${FRAPPE_URL:?FRAPPE_URL is required}"
      : "''${FRAPPE_BRANCH:?FRAPPE_BRANCH is required}"
      : "''${BUILD_IMAGE:?BUILD_IMAGE is required}"
      : "''${BENCH_INIT_SCRIPT:?BENCH_INIT_SCRIPT is required}"
      : "''${CONTAINER_NAME:?CONTAINER_NAME is required}"

      BENCH_DIR="''${BENCH_DIR%/}"
      if [[ -z "$BENCH_DIR" || "$BENCH_DIR" == "/" ]]; then
        echo "ERROR: refusing unsafe BENCH_DIR=\"''${BENCH_DIR}\"" >&2
        exit 1
      fi

      FORCE="''${FORCE:-0}"
      HASH_FILE="''${HASH_FILE:-''${BENCH_DIR}-hash}"
      CACHE_DIR="''${CACHE_DIR:-}"
      CGROUP_PARENT="''${CGROUP_PARENT:-}"

      mkdir -p "$(dirname "$BENCH_DIR")" "$(dirname "$HASH_FILE")"

      SPEC_HASH="$(
        {
          cat "$APPS_JSON" "$BENCH_INIT_SCRIPT"
          printf "%s\n" "$FRAPPE_URL" "$FRAPPE_BRANCH" "$BUILD_IMAGE"
        } | sha256sum | cut -c1-12
      )"

      if [[ "$FORCE" != "1" && -f "$HASH_FILE" && -d "$BENCH_DIR/apps/frappe" && ! -L "$BENCH_DIR" ]] \
         && [[ "$(cat "$HASH_FILE")" == "$SPEC_HASH" ]]; then
        echo "==> spec ''${SPEC_HASH} unchanged at ''${BENCH_DIR}, skipping (use FORCE=1 to rebuild)" >&2
        exit 0
      fi

      work=""
      old=""
      # shellcheck disable=SC2317,SC2329
      cleanup() {
        if [[ -n "$work" && -e "$work" ]]; then
          chmod -R u+w "$work" 2>/dev/null || true
          rm -rf "$work"
        fi
        if [[ -n "$old" && -e "$old" ]]; then
          chmod -R u+w "$old" 2>/dev/null || true
          rm -rf "$old"
        fi
      }
      trap cleanup EXIT

      work="$(mktemp -d "''${BENCH_DIR}.tmp.XXXXXX")"

      userns_args=()
      if [[ $EUID -eq 0 ]]; then
        chown 1000:0 "$work"
        chmod 0770 "$work"
      else
        userns_args=("--userns=keep-id")
        chmod 0770 "$work"
      fi

      cache_args=()
      if [[ -n "$CACHE_DIR" ]]; then
        mkdir -p "$CACHE_DIR"
        if [[ $EUID -eq 0 ]]; then
          chown 1000:0 "$CACHE_DIR"
          chmod 0770 "$CACHE_DIR"
        fi
        cache_args=(
          -v "$(realpath "$CACHE_DIR")":/home/frappe/.cache
          -e "XDG_CACHE_HOME=/home/frappe/.cache"
          -e "UV_CACHE_DIR=/home/frappe/.cache/uv"
          -e "PIP_CACHE_DIR=/home/frappe/.cache/pip"
          -e "YARN_CACHE_FOLDER=/home/frappe/.cache/yarn"
          -e "NPM_CONFIG_CACHE=/home/frappe/.cache/npm"
        )
      fi

      cgroup_args=()
      if [[ -n "$CGROUP_PARENT" ]]; then
        cgroup_args=("--cgroup-parent=''${CGROUP_PARENT}")
      fi

      # HARDEN_ARGS=(
      #   --cap-drop=ALL
      #   --security-opt=no-new-privileges
      #   --pids-limit=2048
      # )

      podman run --rm --replace \
        --name "''${CONTAINER_NAME}-''${SPEC_HASH}" \
        -v "$(realpath "$work")":/home/frappe/frappe-bench \
        -v "$(realpath "$APPS_JSON")":/opt/frappe/apps.json:ro \
        -v "$(realpath "$BENCH_INIT_SCRIPT")":/opt/bench-init.sh:ro \
        -e "FRAPPE_URL=''${FRAPPE_URL}" \
        -e "FRAPPE_BRANCH=''${FRAPPE_BRANCH}" \
        -e "FRAPPE_DOCKER_BUILD=1" \
        -e "UV_LINK_MODE=copy" \
        "''${cache_args[@]}" \
        "''${cgroup_args[@]}" \
        "''${userns_args[@]}" \
        "$BUILD_IMAGE" \
        bash /opt/bench-init.sh

      if [[ ! -d "$work/apps/frappe" ]]; then
        echo "ERROR: bench init did not produce apps/frappe — aborting" >&2
        exit 1
      fi

      # Deferred for now (benchDir kept writable):
      # chown -Rh root:0 "$work"
      # chmod -R a-w "$work"

      rm -f "$HASH_FILE"

      if [[ -L "$BENCH_DIR" ]]; then
        rm -f "$BENCH_DIR"
      elif [[ -e "$BENCH_DIR" ]]; then
        old="$(mktemp -u "''${BENCH_DIR}.old.XXXXXX")"
        mv -T "$BENCH_DIR" "$old"
      fi

      mv -T "$work" "$BENCH_DIR"
      work=""

      if [[ -n "$old" && -e "$old" ]]; then
        chmod -R u+w "$old" 2>/dev/null || true
        rm -rf "$old"
        old=""
      fi

      tmp_hash="$(mktemp "''${HASH_FILE}.XXXXXX")"
      printf "%s\n" "$SPEC_HASH" > "$tmp_hash"
      mv -f "$tmp_hash" "$HASH_FILE"

      echo "==> Bench dir: ''${BENCH_DIR}" >&2
      echo "==> Spec hash: ''${SPEC_HASH} (''${HASH_FILE})" >&2
    '';
  });
in {
  options.myOpt.make-frappe-bench = mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({name, ...} @ innerArgs: let
      cfg = innerArgs.config;
    in {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        autoStart = mkOption {
          type = types.bool;
          default = false;
        };
        readOnlyMode = mkOption {
          type = types.bool;
          default = false;
        };
        force = mkOption {
          type = types.bool;
          default = false;
        };
        benchDir = mkOption {
          type = types.strMatching "^/.+[^/]$";
          example = "/var/lib/${name}/frappe-bench";
        };
        hashFile = mkOption {
          type = types.strMatching "^/.+[^/]$";
          default = "${cfg.benchDir}-hash";
        };
        cacheDir = mkOption {
          type = types.nullOr (types.strMatching "^/.+[^/]$");
          default = "/var/cache/make-frappe-bench/${name}";
          example = "/var/cache/make-frappe-bench/${name}";
        };
        serviceName = mkOption {
          type = types.singleLineStr;
          default = "make-frappe-bench-${name}";
        };
        serviceUnit = mkOption {
          type = types.singleLineStr;
          default = "${cfg.serviceName}.service";
          readOnly = true;
        };
        containerName = mkOption {
          type = types.singleLineStr;
          default = cfg.serviceName;
        };
        cgroup-parent = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };
        before = mkOption {
          type = types.listOf types.singleLineStr;
          default = [];
        };
        requiredBy = mkOption {
          type = types.listOf types.singleLineStr;
          default = [];
        };
        apps = mkOption {
          default = {};
          type = types.attrsOf (types.submodule ({name, ...}: {
            options = {
              enable = mkOption {
                type = types.bool;
                default = true;
              };
              url = mkOption {
                type = types.singleLineStr;
                default = "https://github.com/frappe/${name}";
              };
              branch = mkOption {
                type = types.singleLineStr;
              };
              order = mkOption {
                type = types.int;
                default = 1000;
              };
            };
          }));
        };
        frappe = {
          url = mkOption {
            type = types.singleLineStr;
            default = "https://github.com/frappe/frappe";
          };
          branch = mkOption {
            type = types.singleLineStr;
            example = "v16.25.0";
          };
        };
        build = {
          tag = mkOption {
            type = types.strMatching "^v16\\.[0-9]+\\.[0-9]+$";
            default =
              if (cfg.apps ? "erpnext") && cfg.apps.erpnext.enable
              then cfg.apps.erpnext.branch
              else cfg.frappe.branch; # See https://raw.githubusercontent.com/frappe/frappe_docker/main/docker-bake.hcl
            example = "v16.26.2";
          };
          image = mkOption {
            type = types.singleLineStr;
            default = "docker.io/frappe/build:${cfg.build.tag}";
          };
        };
      };
    }));
  };

  config = mkIf (enabled != {}) {
    assertions = concatLists (mapAttrsToList (name: cfg: let
        enabledApps = filterAttrs (_: a: a.enable) cfg.apps;
      in [
        {
          assertion = !hasPrefix "/nix/store" cfg.benchDir;
          message = "myOpt.make-frappe-bench.${name}.benchDir must not be inside /nix/store (got ${cfg.benchDir}).";
        }
        {
          assertion = !(enabledApps ? "erpnext") || cfg.build.tag == enabledApps.erpnext.branch;
          message = "ERPNext tag and build tag are one. See https://raw.githubusercontent.com/frappe/frappe_docker/main/docker-bake.hcl";
        }
        {
          assertion = !(enabledApps ? "helpdesk") || enabledApps ? "telephony";
          message = "Helpdesk requires Telephony. See https://github.com/frappe/helpdesk";
        }
      ])
      enabled);

    virtualisation.podman.enable = true;

    systemd.services = mkMerge (mapAttrsToList (name: cfg: let
        sliceUnit = toSliceUnit cfg.cgroup-parent;
      in {
        ${cfg.serviceName} = mkMerge [
          {
            wants = ["network-online.target"];
            after = ["network-online.target"];
            inherit (cfg) before requiredBy;
            wantedBy = optional cfg.autoStart "multi-user.target";
            environment =
              {
                BENCH_DIR = cfg.benchDir;
                HASH_FILE = cfg.hashFile;
                APPS_JSON = toString (mkAppsJson name cfg);
                FRAPPE_URL = cfg.frappe.url;
                FRAPPE_BRANCH = cfg.frappe.branch;
                BUILD_IMAGE = cfg.build.image;
                BENCH_INIT_SCRIPT = toString bench-init-script;
                CONTAINER_NAME = cfg.containerName;
                FORCE =
                  if cfg.force
                  then "1"
                  else "0";
              }
              // optionalAttrs (cfg.cacheDir != null) {
                CACHE_DIR = cfg.cacheDir;
              }
              // optionalAttrs (sliceUnit != null) {
                CGROUP_PARENT = sliceUnit;
              };
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = "infinity";
              ExecStart =
                if cfg.readOnlyMode
                then make-frappe-bench-readonly
                else make-frappe-bench;
            };
          }
          (mkIf (sliceUnit != null) {
            serviceConfig.Slice = sliceUnit;
          })
        ];
      })
      enabled);
  };
}
