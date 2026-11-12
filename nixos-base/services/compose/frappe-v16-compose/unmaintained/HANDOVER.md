1. `frappe-v16-compose/unmaintained/` preserves the previous Frappe implementation for reference.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../../../../HANDOVER.md).
    2. `frappe-compose.backup.nix` is excluded from the parent import list.
        1. It declares the same `myOpt.frappe-v16-compose` option tree now separated into `../options.nix`.
        2. Never import both implementations together because their declarations and configuration overlap.
    3. The backup records earlier design choices.
        1. It retains the bench path `/home/frappe/frappe-bench` and database paths `/var/lib/mysql` and `/data`.
        2. Socket directories remain `/run/frappe`, `/run/mysqld`, `/run/valkey-cache`, and `/run/valkey-queue`.
        3. Socket names remain `mysqld.sock`, `valkey.sock`, and `gunicorn.sock`, with Socket.IO on port 9000.
        4. It builds enabled-app JSON and uses the same store-capture approach.
        5. The current implementation extracts options and lifecycle scripts into separate files.
        6. The current implementation also adds read-only deployment mode and `bench-readonly.sh`.
        7. Commented capability-drop experiments document attempted hardening rather than an untouched security surface.
    4. Old host options require migration before reuse.
        1. Replace obsolete `networkNamespace` and `cgroup-parent` settings with `netns-id` and current pass-through wiring.
        2. Let proxy-compose and current activation wiring own startup rather than copying the old `autoStart` option.
        3. Keep the backup syntactically valid for tools that scan dormant Nix files.
    5. Review historical value before deleting the backup.
        1. Check available Git history rather than assuming the original squashed snapshot preserves earlier designs.
        2. Confirm another record of the pre-read-only design exists.
        3. Record any deletion rationale separately from unrelated changes.
    6. Read the related handovers for active behavior and dormant-code policy.
        1. The [live-module handover](../HANDOVER.md) describes scripts and read-only mode.
        2. The [root handover](../../../../../HANDOVER.md) records dormant-directory issue **G3**.
