{ pkgs-unstable, user, ... }:
{
  programs.niri = {
    enable  = true;
    package = pkgs-unstable.niri;  # >= 26.04 for blur

    # Upstream defaults this to true, which routes the portal FileChooser through
    # Nautilus (and pulls it into the dbus packages). We use Thunar (apps.nix), so
    # turn it off — that makes the module emit FileChooser = "gtk" itself, which is
    # the supported way to get the GTK picker instead of overriding config.niri.
    useNautilus = false;
  };

  # TTY1 autologin — zprofile in home/niri.nix execs niri-session
  services.getty.autologinUser = user;

  # wallpaper is managed by noctalia (the shell), not swaybg
  # (NIXOS_OZONE_WL is not here — it applies to any Wayland session, so it lives
  #  in desktop.nix with the rest of the compositor-agnostic layer.)

  # ── xdg portals ──────────────────────────────────────────────────
  # Deliberately empty: portals are compositor-specific (which backend serves
  # screencast depends entirely on the compositor), and `programs.niri` above
  # already configures them for us. It sets xdg.portal.enable, adds the gnome
  # portal (niri is Smithay-based, so screencast goes through GNOME —
  # xdg-desktop-portal-wlr is wlroots-only and captures nothing here), pulls in
  # the gtk portal via wayland-session.nix with enableWlrPortal = false, and
  # writes config.niri with gnome-then-gtk as the default backend order.
  #
  # So don't re-declare any of that here — a hand-written xdg.portal.config.niri
  # OVERRIDES upstream's rather than extending it, which is how you silently lose
  # the Access/Notification/Secret entries it sets. Adding a second compositor
  # means adding its module; its portals come with it.
}
