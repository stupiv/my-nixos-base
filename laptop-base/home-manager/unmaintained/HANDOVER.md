- This is the handover for `laptop-base/home-manager/unmaintained/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It holds one parked home-manager module, `hermes-agent.nix`.
    - `../default.nix` does **not** import it and there is no commented `./unmaintained` line either since it is simply absent, so the whole flake ignores it.

  - `hermes-agent.nix`
    - It imports `inputs.hermes-agent.homeManagerModules.default`, from the flake input `NousResearch/hermes-agent v0.21.7`.
    - It declares `options.myOpt.hermes-agent.enable = mkOption { type = types.bool; default = false; };`.
    - Its config is gated by `mkIf cfg.enable`.
    - Inside, it sets `programs.hermes-agent` with `enable = mkDefault true;` and `desktop.enable = mkDefault true;`.
    - It sets `services.hermes-agent.enable = mkDefault true;` and `workingDirectory = mkDefault config.xdg.userDirs.download;`.
    - Its settings include `display.busy_input_mode = "steer";`.
    - Its settings include `model = { default = ""; provider = ""; base_url = ""; api_mode = ""; };`.
    - Its settings include `agent = { reasoning_effort = ""; service_tier = ""; };`.
    - What it is is the desktop/TUI agent client for the same `hermes-agent` project that [`nixos-base/services/compose/hermes-agent-compose.nix`](../../../nixos-base/services/compose/HANDOVER.md) tries to containerise.
    - The flake input exists in `flake.nix` pinned to `v0.21.7` with a comment explaining that *following* nixpkgs inputs would break the binary cache.
    - There is a matching substituter `hermes-agent.cachix.org` in [`../../common/nixpkgs-overlays.nix`](../../common/HANDOVER.md).

  - Why it is unmaintained
    - `settings.model.{default,provider,base_url,api_mode}` and `settings.agent.{reasoning_effort,service_tier}` are set to **empty strings**, which are placeholders that will produce a non-functional client unless overridden.
      - The commented-out version at the top of `hermes-agent-compose.nix` shows the intended shape with `provider = "openai"` and `base_url = "<litellm>/v1"`.
    - The upstream home-manager module interface is still moving, and the system-side module that would back `services.hermes-agent` is not in this repo at all.
    - It is the only consumer of the `hermes-agent` flake input, so **removing this file would make the input and the cachix substituter dead weight**, meaning you should decide both together.

  - Gotchas
    - **Ordering and scope** matter because `services.hermes-agent` here is a *home-manager* service whose settings block would need a reachable LiteLLM endpoint that lives on the NixOS side as `myOpt.litellm`.
      - There is no plumbing that connects them, unlike the compose module which wires `model.base_url` to `${myOpt.litellm.<name>.url}/v1` automatically.
    - **`workingDirectory = xdg.userDirs.download`** lands in Downloads, and as [`../HANDOVER.md`](../HANDOVER.md) explains, on this profile *all* user dirs point at Downloads so this is the same folder as documents, music and pictures.
    - `enable = mkDefault true` inside `mkIf cfg.enable` is redundant because the module is already gated, but it is the style used repo-wide for "on unless someone says otherwise", so keep it for consistency.
    - Enabling it requires `inputs.hermes-agent` to be present in `extraSpecialArgs`, which `laptop-base/home-manager.nix` provides via `extraSpecialArgs = { inherit inputs; }`, and a different host wiring would need the same.

  - How to revive
    - Fill the empty `settings` values or override them from the host, pointing `base_url` at a LiteLLM instance.
    - Move the file back to `../` and add it to `../default.nix`'s import list.
    - Keep `myOpt.hermes-agent.enable = false` as the default, because it is a heavy desktop client.
    - Check that the cachix substituter is still listed, otherwise the first build compiles a Rust/Electron payload from source.

  - See also
    - [`../HANDOVER.md`](../HANDOVER.md) covers the profile it would join.
    - [`../../../nixos-base/services/compose/HANDOVER.md`](../../../nixos-base/services/compose/HANDOVER.md) covers the server-side counterpart, which is a skeleton referencing a non-existent `myOpt.searxng`.
    - [`../../../HANDOVER.md`](../../../HANDOVER.md) covers the inputs and **G3**, the dormant directories.
