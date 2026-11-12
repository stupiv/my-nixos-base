1. `laptop-base/home-manager/unmaintained/` holds the parked Hermes desktop module.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../../HANDOVER.md).
    2. `../default.nix` does not import `hermes-agent.nix`.
    3. The module wraps the Hermes home-manager integration.
        1. It imports `inputs.hermes-agent.homeManagerModules.default` from pinned version `v0.21.7`.
        2. `myOpt.hermes-agent.enable` defaults to `false` and gates configuration with `mkIf`.
        3. Enabled configuration defaults the program, desktop integration, and user service to enabled.
        4. The working directory defaults to `config.xdg.userDirs.download`.
        5. `display.busy_input_mode` is `steer`.
        6. Model fields `default`, `provider`, `base_url`, and `api_mode` are empty placeholders.
        7. Agent fields `reasoning_effort` and `service_tier` are also empty placeholders.
    4. Revival requires configuration rather than merely adding an import.
        1. Fill the empty settings and provide a reachable LiteLLM endpoint.
        2. Unlike the [server compose module](../../../nixos-base/services/compose/HANDOVER.md), this client has no automatic endpoint wiring.
        3. Move the module into the active profile and register it in `../default.nix`.
        4. Retain the default-disabled toggle and the repository's `mkDefault` style.
        5. Ensure `inputs` reaches the module through home-manager `extraSpecialArgs`.
        6. Check the Hermes [cache configuration](../../common/HANDOVER.md) before accepting a source build.
    5. Existing server usage still depends on the Hermes flake input.
        1. `nixos-base/services/hermes-agent.nix` imports the upstream NixOS module independently of this file.
        2. Server configuration uses `provider = "custom"` and a LiteLLM `base_url` ending in `/v1`.
        3. Removing this parked client therefore does not orphan the input or cache.
        4. The server compose skeleton still has unresolved option and optional SearXNG wiring gaps.
    6. Read the related handovers before revival.
        1. The [profile handover](../HANDOVER.md) describes the shared Downloads directory.
        2. The [compose handover](../../../nixos-base/services/compose/HANDOVER.md) describes server-side Hermes and LiteLLM.
        3. The [root handover](../../../HANDOVER.md) covers inputs and dormant-directory issue **G3**.
