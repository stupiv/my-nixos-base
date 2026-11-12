1. `laptop-base/unmaintained/` holds the parked NixOS desktop-audio microphone module.
    1. These notes describe the unbuilt 2026-11-07 snapshot documented in the [root handover](../../HANDOVER.md).
    2. `laptop-base/default.nix` does not import this directory.
    3. `desktop-mic.nix` remaps a sink monitor into a virtual input device.
        1. `YOUR_SINK_NAME` is hard-coded to `alsa_output.pci-0000_00_1f.3.analog-stereo`.
        2. The `10-desktop-audio-mic` PipeWire Pulse snippet contains a `pulse.cmd` entry with `cmd = "load-module"` and `flags = []`.
        3. It loads `module-remap-source` with the sink's `.monitor` as its master.
        4. The source is named `desktop_audio_mic` and described as `Desktop_Audio_Mic`.
        5. This input captures speaker output for recordings, demonstrations, or calls.
    4. The module is machine-specific and uses the Pulse compatibility layer.
        1. A missing sink causes remap-source creation to fail.
        2. Native PipeWire alternatives include configured nodes, `context.objects`, or `pw-loopback`.
        3. Pulse compatibility must remain enabled through the laptop's `sound.nix`.
    5. Revival requires selecting the actual audio sink.
        1. Inspect sinks with `pactl list short sinks` or `pw-cli ls Node`.
        2. Replace the hard-coded name or expose it as a required `myOpt.desktop-mic.master` option.
        3. Move the module to `laptop-base/` and register it in the active import list.
        4. Preserve the `pulse.cmd` section name and its `flags` list.
        5. The snippet filename may change without renaming the PipeWire section.
        6. Configure recording latency and `stream.dont-remix` on clients as needed.
    6. Read the related handovers before revival.
        1. The [laptop handover](../HANDOVER.md) describes PipeWire and dconf.
        2. The [parked home-manager handover](../home-manager/unmaintained/HANDOVER.md) covers the separate user-module shelf.
        3. The [root handover](../../HANDOVER.md) explains why dormant code still needs valid syntax under **G3**.
