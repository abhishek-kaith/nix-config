{ pkgs, ... }:
{
  # Microphone noise suppression with no app running: a PipeWire filter-chain
  # wraps the RNNoise LADSPA plugin in a virtual source named "Noise Canceling
  # source". Replaces EasyEffects (modules/home/easyeffects.nix) on hosts that
  # import this — one ML denoiser in PipeWire itself, no daemon, no GUI, nothing
  # to keep in sync with a preset format.
  #
  # Pick it once as the default input (Plasma: volume applet → Devices, or
  # `wpctl set-default <id>`). WirePlumber keeps the default device as its own
  # state in ~/.local/state/wireplumber, so there is no clean key to set it from
  # here. With it as the default, the filter still reads from the real mic
  # (the Digital Microphone on t14) — WirePlumber never links it to itself.
  # A new pipewire.conf.d file needs `systemctl --user restart pipewire` or a
  # re-login; nixos-rebuild does not restart the user's PipeWire.
  #
  # Better suppression of babble and keyboard noise, for more CPU: swap the node
  # for DeepFilterNet — plugin "${pkgs.deepfilternet}/lib/ladspa/libdeep_filter_ladspa.so",
  # label "deep_filter_mono".
  services.pipewire.extraConfig.pipewire."99-mic-denoise" = {
    "context.modules" = [
      {
        name = "libpipewire-module-filter-chain";
        args = {
          "node.description" = "Noise Canceling source";
          "media.name" = "Noise Canceling source";
          "filter.graph".nodes = [
            {
              type = "ladspa";
              name = "rnnoise";
              plugin = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so";
              label = "noise_suppressor_mono";
              control = {
                # How sure RNNoise must be that a frame is voice before it
                # opens; below this, the frame is muted. Raise it if keyboard
                # clicks get through, lower it if quiet words get cut.
                "VAD Threshold (%)" = 50.0;
                # Keeps it open this long after speech, so word endings survive.
                "VAD Grace Period (ms)" = 200;
                "Retroactive VAD Grace (ms)" = 0;
              };
            }
          ];
          "capture.props" = {
            "node.name" = "capture.rnnoise_source";
            "node.passive" = true; # only runs while something records from it
            "audio.rate" = 48000; # RNNoise's only rate
          };
          "playback.props" = {
            "node.name" = "rnnoise_source";
            "media.class" = "Audio/Source";
            "audio.rate" = 48000;
          };
        };
      }
    ];
  };
}
