{ inputs, lib, pkgs, ... }:
let
  # What Shift+1..9 types on a US layout (base.nix: keyMap "us"). KDE stores a
  # shifted digit chord as the symbol, so Karousel's Meta+Shift+1 default is
  # never matched — it has to be bound as Meta+! (its own docs say the same).
  shifted = [ "!" "@" "#" "$" "%" "^" "&" "*" "(" ];
  digits  = lib.genList (i: toString (i + 1)) 9;
  forDigits = f: lib.listToAttrs (lib.zipListsWith f digits shifted);
in
{
  # The USER half of the Plasma layer; modules/nixos/plasma.nix is the system
  # half. Shorter than modules/home/cosmic.nix because Plasma solves the hard
  # part of that file itself: kde-gtk-config (from the plasma6 module) rewrites
  # GTK2/3/4 settings.ini and the GSettings keys whenever the Plasma colour
  # scheme changes, so old GTK3 apps follow light/dark with no sync service.

  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  # plasma-manager writes only the keys declared below into Plasma's *rc files,
  # at every activation (overrideConfig stays false). Everything else — panels,
  # theme, wallpaper, every shortcut not named here — stays Plasma's, edited in
  # System Settings. A key named here wins over a GUI edit on the next rebuild,
  # so change these HERE, not in System Settings.
  programs.plasma.enable = true;

  # ── shortcuts: give Karousel its keys ────────────────────────────
  # Karousel's defaults are a WASD layout on Meta, and Plasma 6.6 already owns
  # several of those chords. kglobalaccel hands a chord to whoever registered
  # it first, which is always Plasma, so without this those Karousel actions
  # come up unbound. Checked against the Plasma 6.6 sources (kwin, plasmashell,
  # spectacle), not only Karousel's own list — Meta+A, Meta+Shift+S, Meta+R and
  # Meta+Ctrl+X are clashes its docs do not mention. `[ ]` writes "none".
  programs.plasma.shortcuts = {
    kwin = {
      "Show Desktop"                        = [ ];  # Meta+D, "Peek at Desktop"
      "Overview"                            = [ ];  # Meta+W; Meta+Tab still cycles Overview → Grid
      "Activate Window Demanding Attention" = [ ];  # Meta+Ctrl+A

      "karousel-focus-left"             = "Meta+A";
      "karousel-focus-right"            = "Meta+D";
      "karousel-focus-up"               = "Meta+W";
      "karousel-focus-down"             = "Meta+S";
      "karousel-window-move-left"       = "Meta+Shift+A";
      "karousel-window-move-down"       = "Meta+Shift+S";
      "karousel-columns-squeeze-left"   = "Meta+Ctrl+A";
      "karousel-cycle-preset-widths"         = "Meta+R";
      "karousel-cycle-preset-widths-reverse" = "Meta+Shift+R";
      "karousel-columns-width-equalize" = "Meta+Ctrl+X";
    }
    // forDigits (n: _: lib.nameValuePair "karousel-focus-${n}" "Meta+${n}")
    // forDigits (n: s: lib.nameValuePair "karousel-window-move-to-column-${n}" "Meta+${s}")
    // forDigits (n: s: lib.nameValuePair "karousel-column-move-to-column-${n}" "Meta+Ctrl+${s}");

    plasmashell = {
      "next activity"     = [ ];  # Meta+A — one activity here, nothing to walk
      "previous activity" = [ ];  # Meta+Shift+A
      "clipboard_action"  = [ ];  # Meta+Ctrl+X, Klipper's URL-action popup.
                                  # Clipboard history (Meta+V) is untouched.
    }
    # Meta+1..9 — "activate task manager entry N". Karousel's focus-column-N
    # does the same job for a scrolling row.
    // forDigits (n: _: lib.nameValuePair "activate task manager entry ${n}" [ ]);

    "org.kde.spectacle.desktop" = {
      "_launch"      = "Print";  # drops Meta+Shift+S; PrtSc still opens Spectacle
      "RecordRegion" = [ ];      # Meta+R and Meta+Shift+R. Screen and window
                                 # recording keep Meta+Alt+R / Meta+Ctrl+R.
    };
  };

  # ── sleep: match laptop.nix ──────────────────────────────────────
  # PowerDevil holds logind's lid inhibitor while Plasma runs, so laptop.nix's
  # HandleLidSwitch=suspend-then-hibernate only applies at the greeter. This is
  # the in-session equivalent; it calls logind's SuspendThenHibernate, so
  # laptop.nix's HibernateDelaySec (30min) still sets the delay.
  programs.plasma.powerdevil = lib.genAttrs [ "AC" "battery" "lowBattery" ] (_: {
    whenSleepingEnter = "standbyThenHibernate";
  });

  # ── pinentry ─────────────────────────────────────────────────────
  # pinentry-gnome3 (the default in pass.nix) draws through gcr's prompter,
  # which only gnome-keyring registers — and this host runs KWallet instead
  # (modules/nixos/plasma.nix). Without the prompter it would fall back to a
  # curses prompt, which `pass -c` from a launcher has nowhere to draw.
  services.gpg-agent.pinentry.package = pkgs.pinentry-qt;

  # ── mime defaults for Plasma's own apps ──────────────────────────
  # The DE-agnostic handlers (mpv, qimgv) are in modules/home/xdg.nix and the
  # browser's in its own module; these are the ones that change with the
  # desktop. defaultApplications merges across modules into one list.
  xdg.mimeApps.defaultApplications = {
    "inode/directory"           = "org.kde.dolphin.desktop";
    "x-scheme-handler/terminal" = "org.kde.konsole.desktop";
    "text/plain"                = "org.kde.kate.desktop";
    "application/pdf"           = "org.kde.okular.desktop";
  };
}
