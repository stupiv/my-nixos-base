# HANDOVER — `laptop-base/home-manager/unmaintained/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

One parked home-manager module: `hermes-agent.nix`. `../default.nix` does **not** import it (there is no commented
`./unmaintained` line either — it is simply absent), so the whole flake ignores it.

## `hermes-agent.nix`

```nix
imports = [ inputs.hermes-agent.homeManagerModules.default ];   // flake input: NousResearch/hermes-agent v0.21.7
options.myOpt.hermes-agent.enable = mkOption { type = types.bool; default = false; };
config = mkIf cfg.enable {
  programs.hermes-agent = { enable = mkDefault true; desktop.enable = mkDefault true; };
  services.hermes-agent = {
    enable = mkDefault true;
    workingDirectory = mkDefault config.xdg.userDirs.download;
    settings = {
      display.busy_input_mode = "steer";
      model = { default = ""; provider = ""; base_url = ""; api_mode = ""; };
      agent = { reasoning_effort = ""; service_tier = ""; };
    };
  };
};
```

What it is: the desktop/TUI agent client for the same `hermes-agent` project that
[`nixos-base/services/compose/hermes-agent-compose.nix`](../../../nixos-base/services/compose/HANDOVER.md) tries to
containerise. The flake input exists (`flake.nix`, pinned to `v0.21.7`, with a comment explaining that *following*
nixpkgs inputs would break the binary cache) and there is a matching substituter in
[`../../common/nixpkgs-overlays.nix`](../../common/HANDOVER.md) (`hermes-agent.cachix.org`).

## Why it is unmaintained

- `settings.model.{default,provider,base_url,api_mode}` and `settings.agent.{reasoning_effort,service_tier}` are set to
  **empty strings** — placeholders that will produce a non-functional client unless overridden. The commented-out
  version at the top of `hermes-agent-compose.nix` shows the intended shape (`provider = "openai"`,
  `base_url = "<litellm>/v1"`).
- The upstream home-manager module interface is still moving (the system-side module that would back
  `services.hermes-agent` is not in this repo at all).
- It is the only consumer of the `hermes-agent` flake input, so **removing this file would make the input and the
  cachix substituter dead weight** — decide both together.

## Gotchas

- **Ordering / scope:** `services.hermes-agent` here is a *home-manager* service; the settings block would need a
  reachable LiteLLM endpoint, which lives on the NixOS side (`myOpt.litellm`). There is no plumbing that connects them,
  unlike the compose module which wires `model.base_url` to `${myOpt.litellm.<name>.url}/v1` automatically.
- **`workingDirectory = xdg.userDirs.download`** — see [`../HANDOVER.md`](../HANDOVER.md): on this profile *all* user
  dirs point at Downloads, so this is the same folder as documents/music/pictures.
- `enable = mkDefault true` inside `mkIf cfg.enable` is redundant (the module is already gated), but it is the style used
  repo-wide for "on unless someone says otherwise" — keep it for consistency.
- Enabling it requires `inputs.hermes-agent` to be present in `extraSpecialArgs`, which `laptop-base/home-manager.nix`
  provides (`extraSpecialArgs = { inherit inputs; }`). A different host wiring would need the same.

## How to revive

1. Fill the empty `settings` values (or override them from the host), pointing `base_url` at a LiteLLM instance.
2. Move the file back to `../` and add it to `../default.nix`'s import list.
3. Keep `myOpt.hermes-agent.enable = false` as the default; it is a heavy desktop client.
4. Check the cachix substituter is still listed, otherwise the first build compiles a Rust/Electron payload from source.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — the profile it would join
- [`../../../nixos-base/services/compose/HANDOVER.md`](../../../nixos-base/services/compose/HANDOVER.md) — the server-side
  counterpart (a skeleton, references a non-existent `myOpt.searxng`)
- [`../../../HANDOVER.md`](../../../HANDOVER.md) — §3 inputs, **G3** (dormant directories)
