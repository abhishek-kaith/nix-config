{ pkgs, ... }:
{
  # `pass` password store (+ TOTP via pass-otp) on top of GnuPG.
  #
  # The data is NOT declared here: ~/.gnupg (keys, keyboxd pubring, trustdb) and
  # ~/.password-store (git repo of *.gpg files, .gpg-id names the key) are user
  # state, restored once from the migration backup and thereafter owned by
  # `gpg` / `pass git`. Home-manager only links gpg.conf + gpg-agent.conf into
  # ~/.gnupg and never touches the keyrings (mutableKeys/mutableTrust default on).

  # ── gpg ──────────────────────────────────────────────────────────
  # homedir defaults to ~/.gnupg — the restored dir has common.conf with
  # `use-keyboxd`, so public keys live in public-keys.d/pubring.db, not
  # pubring.kbx; gnupg 2.4 starts keyboxd on demand, nothing to configure.
  programs.gpg.enable = true;

  # ── gpg-agent ────────────────────────────────────────────────────
  # Socket-activated systemd user service; the first `gpg`/`pass` call starts it.
  services.gpg-agent = {
    enable = true;

    # pinentry-gnome3 talks to gcr's SystemPrompter over D-Bus rather than
    # drawing its own window. Under COSMIC that prompter is provided by
    # gnome-keyring (services.gnome.gnome-keyring in modules/nixos/desktop.nix,
    # `busctl --user list --activatable | grep Prompter` confirms), so the
    # passphrase dialog is a GTK4 prompt that follows the GTK light/dark sync
    # instead of a foreign Qt/GTK2 box. If the Secret Service ever goes away,
    # swap for pkgs.pinentry-qt — no other change needed.
    pinentry.package = pkgs.pinentry-gnome3;

    # Cache the unlocked key: 1h idle, 8h absolute. gpg's own defaults (10min /
    # 2h) mean re-typing the passphrase for every OTP while logging into things;
    # 8h caps the exposure of an unlocked, unattended session at a work day.
    defaultCacheTtl = 3600;
    maxCacheTtl     = 28800;

    # No SSH support: gcr-ssh-agent (from gnome-keyring) already owns SSH_AUTH_SOCK
    # in the COSMIC session, and ssh keys live in ~/.ssh, not on the gpg key.
    enableSshSupport = false;
  };

  # ── pass ─────────────────────────────────────────────────────────
  # withExtensions puts pass-otp on pass's extension path so `pass otp <entry>`
  # prints the current code and `pass otp -c` copies it. Entries are ordinary
  # pass files whose content is an otpauth:// URI (the */otp and */totp ones in
  # the store). Store dir stays pass's default ~/.password-store, matching the
  # restored repo, so `settings` is left empty on purpose.
  # `pass -c` uses wl-copy under Wayland — wl-clipboard is in packages.nix.
  programs.password-store = {
    enable  = true;
    package = pkgs.pass.withExtensions (exts: [ exts.pass-otp ]);
  };

  # Adding a new TOTP from a QR screenshot:
  #   zbarimg -q --raw qr.png | pass otp insert <site>/otp
  home.packages = [ pkgs.zbar ];
}
