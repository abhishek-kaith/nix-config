{ ... }:
{
  # EasyEffects — PipeWire effects processing for the MICROPHONE chain.
  # Output/speaker processing is deliberately left alone.
  #
  # Nothing extra needs installing: nixpkgs already wraps easyeffects with
  # LADSPA_PATH pointing at deepfilternet and LV2_PATH at calf/lsp-plugins, so
  # every plugin below resolves out of the box. (Without that wrapper the Deep
  # Noise Remover fails at runtime with "libdeep_filter_ladspa is not installed".)
  #
  # The daemon needs programs.dconf.enable at the system level — already set in
  # modules/nixos/desktop.nix. It runs `easyeffects --hide-window --service-mode`
  # under graphical-session.target; launch `easyeffects` for the GUI to tweak.
  services.easyeffects = {
    enable = true;
    preset = "mic"; # --load-preset; matches the extraPresets attr below
  };

  # Preset lands in $XDG_DATA_HOME/easyeffects/input/mic.json.
  #
  # Only keys verified against easyeffects 8.x `*_preset.cpp` are set. Every key
  # is read with json.value(key, default), so anything omitted falls back to the
  # plugin's own default — but the per-plugin OBJECT must exist (it is read with
  # .at(), which throws), hence the empty-ish blocks rather than dropping them.
  #
  # Chain order is signal order: clean up → level → colour → final stage.
  services.easyeffects.extraPresets.mic.input = {
    blocklist = [ ];

    plugins_order = [
      "rnnoise#0"
      "deepfilternet#0"
      "speex#0"
      "exciter#0"
      "stereo_tools#0"
    ];

    # 1. RNNoise — fast RNN denoiser, does the bulk of the steady-state removal.
    "rnnoise#0" = {
      bypass = false;
      "use-standard-model" = true; # bundled model; no external .rnnn to manage
      wet = 0.0; # dB of processed signal; 0 = fully wet, i.e. full effect
    };

    # 2. DeepFilterNet — heavier ML denoiser for what RNNoise leaves behind.
    #    NOTE: this is the second denoiser in a row. Stacking two ML denoisers can
    #    sound over-processed / "underwater" on some mics. If voices sound thin,
    #    set bypass = true on ONE of these two — that is the whole fix.
    #    attenuation-limit caps how much it is allowed to remove (dB); keeping it
    #    below the default ceiling leaves a little room tone so speech stays natural.
    "deepfilternet#0" = {
      bypass = false;
      "attenuation-limit" = 60.0;
      "post-filter-beta" = 0.02;
    };

    # 3. Speex — used here for levelling and dereverb, NOT denoise: its denoiser
    #    would be the third in the chain and just fights the two above.
    "speex#0" = {
      bypass = false;
      "enable-denoise" = false;
      "enable-agc" = true; # automatic gain — evens out how close you sit to the mic
      "enable-dereverb" = true; # takes some of the room off
    };

    # 4. Exciter — adds high harmonics so speech cuts through after all that
    #    subtractive processing. Gentle: denoisers dull the top end, this restores
    #    presence rather than adding brightness for its own sake.
    "exciter#0" = {
      bypass = false;
      amount = 2.0;
      harmonics = 8.5;
      blend = 0.0;
    };

    # 5. Stereo Tools — final stage. A laptop mic is effectively mono, so this is
    #    mostly here to keep both channels identical and catch stray peaks.
    "stereo_tools#0" = {
      bypass = false;
      softclip = true;
      "stereo-base" = 0.0;
    };
  };
}
