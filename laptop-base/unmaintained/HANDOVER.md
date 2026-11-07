# HANDOVER — `laptop-base/unmaintained/`

> Snapshot 2026-11-07 · branch `arena/a7026f5a-my-nixos-base` · commit `66ded62` · not build-tested.

## What this directory is for

One parked **NixOS** module (not home-manager — that is the sibling
[`../home-manager/unmaintained/`](../home-manager/unmaintained/HANDOVER.md)). `laptop-base/default.nix` does not import
it, so it is inert.

## `desktop-mic.nix`

```nix
let YOUR_SINK_NAME = "alsa_output.pci-0000_00_1f.3.analog-stereo"; in {
  services.pipewire.extraConfig.pipewire-pulse."10-desktop-audio-mic" = {
    "pulse.cmd" = [ { cmd = "load-module";
                      args = "module-remap-source "
                           + "master=${YOUR_SINK_NAME}.monitor "
                           + "source_name=desktop_audio_mic "
                           + "source_properties=device.description=Desktop_Audio_Mic";
                      flags = []; } ];
  };
}
```

What it does: creates a virtual PulseAudio/PipeWire **input** device that records whatever is playing on the speakers, by
remapping the sink's `.monitor` source. Useful for screen recording, demos, or feeding system audio into a call.

## Why it is unmaintained

- `YOUR_SINK_NAME` is a **hard-coded ALSA device name** from one specific machine (`pci-0000_00_1f.3`, i.e. Intel HDA on
  a particular laptop). On any other machine the module loads a remap source pointing at a non-existent master, and
  `module-remap-source` fails (usually silently in the journal).
- `pulse.cmd` is the *pulse* compatibility shim; a native PipeWire setup would express the same thing as a
  `context.objects` / `node` in `pipewire.conf` or via `pw-loopback`. This file is the older, shim-based approach.
- It assumes `services.pipewire.pulse.enable` (true via [`../sound.nix`](../HANDOVER.md)) and no namespace/policy rules
  that would block a remap source.

## If you want it back

1. Find your real sink: `pactl list short sinks` (or `pw-cli ls Node`).
2. Replace `YOUR_SINK_NAME`, or better — make it an option:
   `myOpt.desktop-mic.master = mkOption { type = types.singleLineStr; }` and interpolate it, so the module is portable.
3. Move the file to `laptop-base/` and add it to the import list. It belongs on the laptop only; `sound.nix` is where the
   PipeWire enable flag lives.

## Gotchas

- **The `"pulse.cmd"` key name is load-bearing.** `services.pipewire.extraConfig.pipewire-pulse` writes a
  `pipewire-pulse.conf.d` snippet; the top-level keys must be real PipeWire config sections (`pulse.cmd`,
  `context.objects`, …). Renaming the attribute `10-desktop-audio-mic` is free (it is the filename); renaming
  `pulse.cmd` is not.
- `flags = []` must stay — the option type expects a list, and omitting it changes the generated JSON shape.
- Remap sources inherit the sink's sample rate/latency; for recording, set `stream.dont-remix` / latency options on the
  *client*, not here.
- Since it is inert, a grammar error here breaks only tooling (formatters, LSPs), not builds — see **G3** in the root
  handover.

## See also

- [`../HANDOVER.md`](../HANDOVER.md) — `sound.nix` (PipeWire + dconf) and `vi-ime.nix` (the other audio-adjacent opt-in)
- [`../../HANDOVER.md`](../../HANDOVER.md) — G3
