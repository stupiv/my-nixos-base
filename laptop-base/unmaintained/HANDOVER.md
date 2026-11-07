- This is the handover for `laptop-base/unmaintained/`.
  - Snapshot
    - The source snapshot is dated 2026-11-07 on branch `arena/a7026f5a-my-nixos-base` at commit `66ded62` and was not build-tested.
    - This file was reshaped into nested bullets on 2026-11-07 (branch `arena/056af839-my-nixos-base`, commit `c103788`) without re-verifying its claims.

  - What this directory is for
    - It holds one parked **NixOS** module, not a home-manager one, since that is the sibling [`../home-manager/unmaintained/`](../home-manager/unmaintained/HANDOVER.md).
    - `laptop-base/default.nix` does not import it, so it is inert.

  - `desktop-mic.nix`
    - It binds `let YOUR_SINK_NAME = "alsa_output.pci-0000_00_1f.3.analog-stereo"; in { … }`.
    - It sets `services.pipewire.extraConfig.pipewire-pulse."10-desktop-audio-mic"` with a `"pulse.cmd"` list.
    - That list contains one entry with `cmd = "load-module";` and `flags = [];`.
    - Its `args` concatenate `"module-remap-source "`, `"master=${YOUR_SINK_NAME}.monitor "`, `"source_name=desktop_audio_mic "` and `"source_properties=device.description=Desktop_Audio_Mic"`.
    - What it does is create a virtual PulseAudio/PipeWire **input** device that records whatever is playing on the speakers by remapping the sink's `.monitor` source.
    - That is useful for screen recording, demos, or feeding system audio into a call.

  - Why it is unmaintained
    - `YOUR_SINK_NAME` is a **hard-coded ALSA device name** from one specific machine, namely `pci-0000_00_1f.3` for Intel HDA on a particular laptop.
      - On any other machine the module loads a remap source pointing at a non-existent master and `module-remap-source` fails, usually silently in the journal.
    - `pulse.cmd` is the *pulse* compatibility shim, whereas a native PipeWire setup would express the same thing as a `context.objects` or `node` in `pipewire.conf` or via `pw-loopback`, so this file is the older shim-based approach.
    - It assumes `services.pipewire.pulse.enable`, which is true via `../sound.nix` as described in [`../HANDOVER.md`](../HANDOVER.md), and no namespace or policy rules that would block a remap source.

  - If you want it back
    - Find your real sink with `pactl list short sinks` or `pw-cli ls Node`.
    - Replace `YOUR_SINK_NAME`, or better make it an option such as `myOpt.desktop-mic.master = mkOption { type = types.singleLineStr; }` and interpolate it so the module is portable.
    - Move the file to `laptop-base/` and add it to the import list, because it belongs on the laptop only and `sound.nix` is where the PipeWire enable flag lives.

  - Gotchas
    - **The `"pulse.cmd"` key name is load-bearing**, because `services.pipewire.extraConfig.pipewire-pulse` writes a `pipewire-pulse.conf.d` snippet whose top-level keys must be real PipeWire config sections such as `pulse.cmd` and `context.objects`.
      - Renaming the attribute `10-desktop-audio-mic` is free since it is the filename, but renaming `pulse.cmd` is not.
    - `flags = []` must stay, because the option type expects a list and omitting it changes the generated JSON shape.
    - Remap sources inherit the sink's sample rate and latency, so for recording set `stream.dont-remix` and latency options on the *client* rather than here.
    - Since it is inert, a grammar error here breaks only tooling such as formatters and LSPs rather than builds, as covered by **G3** in the root handover.

  - See also
    - [`../HANDOVER.md`](../HANDOVER.md) covers `sound.nix` with PipeWire and dconf, plus `vi-ime.nix` as the other audio-adjacent opt-in.
    - [`../../HANDOVER.md`](../../HANDOVER.md) covers **G3**.
