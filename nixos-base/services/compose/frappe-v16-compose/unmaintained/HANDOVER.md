- This is the handover for `nixos-base/services/compose/frappe-v16-compose/unmaintained/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It holds one file, `frappe-compose.backup.nix` at 576 lines, which is the **previous generation** of the Frappe module kept as a reference.
    - Nothing imports it, because `frappe-v16-compose/default.nix` lists only `./frappe-compose.nix` and `./options.nix` with no commented reference to this directory either.

  - Why it is worth keeping, and what to look at in it
    - It is the only place where the *older* design decisions are still visible, which is useful when you are wondering "why is `frappe-compose.nix` like that?".
    - It **declares its own options** for `myOpt.frappe-v16-compose`, the same option tree that is now split out into `../options.nix`, so diffing the two is the fastest way to see which options are new.
    - It shares the same in-container constants as the current file, namely `/home/frappe/frappe-bench`, `/var/lib/mysql`, `/data`, `/run/frappe`, `/run/mysqld`, `/run/valkey-cache`, `/run/valkey-queue`, `mysqld.sock`, `valkey.sock`, `gunicorn.sock` and socketio port `9000`, so the contract with the shell scripts did not change during the rewrite.
    - It builds `apps.json` the same way with `pkgs.writeText` plus `builtins.toJSON` of the enabled apps, and uses the same `frappe-bench-store` wrapper around `../../frappe-bench-store.sh`.
    - What changed in the rewrite, and therefore what *not* to copy back:
      - Options were extracted to `../options.nix`, so this file no longer competes for the same `myOpt` keys.
      - `readOnlyMode` and `bench-readonly.sh` were added, since the old file has no read-only path.
      - The create-site, migrate and configurator logic moved into standalone `.sh` files that are also documented.
      - Hardening came later, and the current file has the commented-out `--cap-drop=ALL` block, meaning hardening was *tried* and backed off rather than forgotten.

  - Gotchas
    - **Do not add this file to an import list.**
      - It redeclares `options.myOpt.frappe-v16-compose`, so importing it alongside `../options.nix` would be a duplicate-declaration error or, worse, a silent merge of two incompatible option trees depending on the type.
    - It also declares `myOpt` sub-options that the current module does not, namely `networkNamespace`, `cgroup-parent` and `autoStart`, so a host config copied from it will reference options that no longer exist.
      - If someone hands you such a config, the migration is to drop `networkNamespace` and `cgroup-parent` in favour of `netns-id` plus the `modules.*` pass-throughs, and to let `proxy-compose` own `autoStart`.
    - It is inert but **not free**, because `nix flake check` does not import it yet any tool that scans `*.nix` such as formatters, `deadnix` or an editor's `nixd` will still parse it, so keep it syntactically valid.
    - The `unmaintained/` name here is a *convention* rather than a mechanism, because unlike `nixos-base/unmaintained/`, which is excluded from the import graph by omission, this directory relies on the parent import list omitting it.

  - If you plan to delete it
    - Check first that `git log` is a single squashed commit, so git will **not** preserve the history you are deleting.
    - Check also that there is no other record of the pre-read-only design.
    - If you decide to delete, do it in its own commit with the rationale in the message.

  - See also
    - [`../HANDOVER.md`](../HANDOVER.md) covers the live module, its scripts and the `readOnlyMode` mechanism.
    - [`../../../../HANDOVER.md`](../../../../HANDOVER.md) covers **G3**, the dormant directories.
