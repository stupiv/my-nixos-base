let
  YOUR_SINK_NAME = "alsa_output.pci-0000_00_1f.3.analog-stereo";
in {
  services.pipewire.extraConfig.pipewire-pulse."10-desktop-audio-mic" = {
    "pulse.cmd" = [
      {
        cmd = "load-module";
        args =
          "module-remap-source "
          + "master=${YOUR_SINK_NAME}.monitor "
          + "source_name=desktop_audio_mic "
          + "source_properties=device.description=Desktop_Audio_Mic";
        flags = [];
      }
    ];
  };
}
