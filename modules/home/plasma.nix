{ config, inputs, lib, pkgs, repoDir, ... }:
{
  # The USER half of the Plasma layer; modules/nixos/plasma.nix is the system
  # half. Shorter than modules/home/cosmic.nix because Plasma solves the hard
  # part of that file itself: kde-gtk-config (from the plasma6 module) rewrites
  # GTK2/3/4 settings.ini and the GSettings keys whenever the Plasma colour
  # scheme changes, so old GTK3 apps follow light/dark with no sync service.

  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  # plasma-manager reaches Plasma's settings in two different ways:
  #
  #  - KEYS (fonts, shortcuts, krunnerrc, kwinrc, powerdevilrc, baloofilerc,
  #    the animation speed, ...) are written into the *rc files at every
  #    activation (overrideConfig stays false). One named here wins over a GUI
  #    edit on the next rebuild, so change those HERE.
  #  - The LOOK (`workspace` below: colour scheme, Plasma style, icons, cursor,
  #    wallpaper) and the PANEL are applied by login scripts that run once per
  #    change of their value here (a checksum in ~/.local/share/plasma-manager).
  #    Change them freely in System Settings: they are re-applied only when
  #    the value in this file is edited.
  #
  # Everything not named here is Plasma's alone, on purpose: the accent colour
  # (System Settings → Colors; "From current wallpaper" is ticked there, and a
  # grey wallpaper like the Fuji one leaves it Breeze blue), light/dark,
  # widget settings, and every other shortcut.
  #
  # Keeping a GUI change: `nix run --inputs-from ~/nix-config plasma-manager`
  # runs rc2nix, which prints the live Plasma config as Nix — grep it for the
  # key and copy it here.
  programs.plasma.enable = true;

  # ── look ─────────────────────────────────────────────────────────
  # Breeze Dark set piece by piece rather than through `lookAndFeel`: applying
  # a global theme package also resets the panel layout, and the panel is
  # declared below. kde-gtk-config carries the colour scheme into GTK apps.
  # These are the apply-once kind (see the top of the file): a starting point
  # that System Settings can change from there. Applying a Global Theme there
  # replaces ALL of them (icons back to Breeze too); to go light by hand, pick
  # Breeze Light under Colors instead, and "Tela circle light" under Icons.
  programs.plasma.workspace = {
    colorScheme = "BreezeDark";
    # Plasma style (the bar, its popups, OSDs): Breeze in the colours of the
    # current scheme, so the bar follows a switch to light, with a rounded
    # accent box instead of an underline on an item whose popup is open
    # (pkgs/breeze-boxed). Utterly-Round was tried here and dropped: its
    # upstream stopped in 2024, and Breeze moves with every Plasma release.
    theme       = "breeze-boxed";
    # Tela-circle: every app a flat colour circle, a look of its own rather
    # than a copy of macOS or Windows, and plain one-colour tray icons (with
    # a bell for notifications, see pkgs/tela-circle-plasma). Picked over
    # Colloid, whose rounded squares lean macOS and whose tray arrow was a
    # large chevron, and Papirus, whose solid tray icons looked heavy.
    iconTheme   = "Tela-circle-dark";
    cursor      = { theme = "breeze_cursors"; size = 24; };
    wallpaper   = "${repoDir}/config/wallpapers/minimal-02.jpg";
    splashScreen.theme = "None";   # autologin already lands straight on the desktop
  };
  # The lock screen shows the desktop's picture rather than Plasma's
  # default one. A KEY, written at every activation (see the top of the file).
  programs.plasma.kscreenlocker.appearance.wallpaper = config.programs.plasma.workspace.wallpaper;

  home.packages = [
    (pkgs.callPackage ../../pkgs/breeze-boxed { })
    (pkgs.callPackage ../../pkgs/tela-circle-plasma { })
    pkgs.kdePackages.kcalc   # floats (config/konveyor/config.kdl); KRunner's `=` covers quick sums
  ];

  # ── app style: Darkly ───────────────────────────────────────────
  # Darkly (installed by modules/nixos/plasma.nix) is a Breeze-like Qt style
  # that can draw parts of a window see-through, with KWin's blur behind:
  # toolbars, menus, tabs and Dolphin's sidebar turn to frosted glass, while
  # the content (file list, text) stays solid to keep it readable. KDE/Qt apps
  # only — GTK apps and browsers draw themselves. widgetStyle is a KEY (written
  # every activation); System Settings → Application Style → Darkly's gear
  # tunes the opacities live, until the next rebuild writes these back.
  programs.plasma.workspace.widgetStyle = "Darkly";
  programs.plasma.configFile.darklyrc = {
    # Buttons, fields and menus rounded like the windows (Konveyor's 6px)
    # rather than Darkly's 9px.
    Common.CornerRadius = 6;
    Style = {
      ToolBarOpacity        = 75;
      MenuBarOpacity        = 75;
      TabBarOpacity         = 75;
      MenuOpacity           = 85;
      DolphinSidebarOpacity = 65;
    };
  };

  # Blur behind anything translucent (the panel, the Konsole below) and a
  # slight dim on every window but the focused one: with title bars hidden,
  # the dim is what makes the active column obvious at a glance, alongside
  # Konveyor's focus ring.
  programs.plasma.kwin.effects = {
    blur.enable        = true;
    dimInactive.enable = true;
  };
  # Popups from the bar (tray, clock, workspaces) appear at once instead of
  # sliding down out of it: the slide read as a delay on every click.
  programs.plasma.configFile.kwinrc.Plugins.slidingpopupsEnabled = false;

  # Night Light: warmer screen from sunset to sunrise, with the times worked
  # out from where the laptop is (geoclue, which the plasma6 module enables).
  # Brightness and Color, behind the tray's ^ arrow, pauses it for colour work.
  # No `mode`: KWin 6.7 knows only Constant and DarkLight (Plasma's shared
  # day/night schedule, its default), and plasma-manager's enum still offers
  # the old automatic/location/times values, which KWin no longer reads.
  programs.plasma.kwin.nightLight.enable = true;

  # Konsole: Plasma's own terminal, kept as the fallback now that Ghostty
  # (ghostty.nix) is Meta+Return. Breeze at 90% opacity, blurred behind (see
  # the scheme's header) — the same look as Ghostty's config.
  # The font is spelled out because a generated profile no longer inherits
  # the system fixed-width one.
  programs.konsole = {
    enable = true;
    customColorSchemes.BreezeGlass = ../../config/konsole/BreezeGlass.colorscheme;
    defaultProfile = "Main";
    profiles.Main = {
      colorScheme = "BreezeGlass";
      font = { name = "Iosevka Nerd Font"; size = 11; };
    };
  };

  # Inter for the UI (installed by modules/nixos/plasma.nix); the terminal
  # font is desktop.nix's monospace default, which Konsole picks up from here.
  # Point sizes are before display scaling: 125% on t14 makes 10pt read as 12.5.
  programs.plasma.fonts =
    let inter = pointSize: { family = "Inter"; inherit pointSize; };
    in {
      general     = inter 10;
      menu        = inter 10;
      toolbar     = inter 10;
      windowTitle = inter 10;
      small       = inter 8;
      fixedWidth  = { family = "Iosevka Nerd Font"; pointSize = 11; };
    };

  # ── panel: one slim bar along the top ────────────────────────────
  # Workspaces on the left, clock in the middle, tray on the right. There is
  # no task manager: Konveyor's row is the window list, and Meta opens KRunner.
  # Declaring panels makes plasma-manager own ALL of them: when this list
  # changes, the next login deletes every panel and rebuilds these, so a panel
  # edited in the GUI only lasts until then.
  programs.plasma.panels = [
    {
      location = "top";
      # 24 rather than 28: in a bar this slim Plasma draws tray icons at
      # 16px instead of 22 (scaleToFit below).
      height   = 24;
      floating = false;
      opacity  = "translucent";   # see-through, with the blur effect behind it
      widgets = [
        # pkgs/workspace-indicator: the 1, 2, 3 that Mod+1..9 jump to, in a
        # row, where Plasma's pager would stack them in a column under Konveyor.
        "workspace-indicator"
        { panelSpacer.expanding = true; }
        {
          digitalClock = {
            time.format   = "24h";
            date.format.custom = "ddd d MMM";
            date.position = "besideTime";
            # A fixed size: left on auto, the clock grows to fill the bar's
            # height and towers over everything else in it. Inter 7, small
            # like a phone's status bar; weight is on Qt 6's 1–1000 scale
            # (400 regular, 500 medium), so the option's default of 50 would
            # be hairline.
            font = { family = "Inter"; size = 7; weight = 500; };
          };
        }
        { panelSpacer.expanding = true; }
        {
          systemTray = {
            # Small icons (16px in the 24px bar, Plasma's smallest standard
            # size) with room between them.
            icons = { scaleToFit = true; spacing = "medium"; };
            items = {
              # Always in the bar (Plasma sorts them itself).
              shown = [
                "org.kde.plasma.notifications"
                "org.kde.plasma.clipboard"
                "org.kde.plasma.volume"
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.battery"
              ];
              # Always behind the arrow. Anything not named in either list
              # (USB drives, the camera-in-use light) shows only while active.
              hidden = [
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.mediacontroller"
                "org.kde.plasma.brightness"
                "org.kde.kdeconnect"
                "org.kde.merkuro.contact.applet"
              ];
            };
          };
        }
      ];
    }
  ];

  # ── Meta: a centred, Spotlight-style search ──────────────────────
  # Tapping Meta alone opens KRunner (apps, files, settings, calculator, unit
  # conversion, `=` for maths) in the middle of the screen, instead of the
  # application menu. It is a modifier-only shortcut, which only kwinrc can
  # bind; Alt+Space still opens it too. Typing on an empty desktop starts it.
  programs.plasma.configFile.kwinrc.ModifierOnlyShortcuts.Meta = "org.kde.krunner,/App,,toggleDisplay";
  programs.plasma.krunner = {
    position                    = "center";
    activateWhenTypingOnDesktop = true;
    historyBehavior             = "enableSuggestions";
    # Meta+Space is the launcher key on most tiling setups (and Spotlight's);
    # KDE's own Alt+Space / Alt+F2 stay.
    shortcuts.launch = [ "Meta+Space" "Alt+Space" "Alt+F2" "Search" ];
  };

  # The terminal Plasma opens for "Open Terminal Here" (Dolphin's F4), the
  # run-in-terminal option in KRunner, and .desktop files with Terminal=true.
  # The mime handler for the same job lives with the terminal, in ghostty.nix.
  programs.plasma.configFile.kdeglobals.General = {
    TerminalApplication = "ghostty";
    TerminalService     = "com.mitchellh.ghostty.desktop";
  };

  # ── Konveyor: the tiling config ──────────────────────────────────
  # Out-of-store, like nvim and starship: ~/.config/konveyor/config.kdl IS
  # config/konveyor/config.kdl in this repo, so a save is live immediately
  # (Konveyor watches the file) with no rebuild. Konveyor's settings page edits
  # the same file through the link — Qt's QSaveFile resolves symlinks before
  # its atomic rename — so GUI changes land in the repo too. Check a hand edit
  # with `konveyor validate`.
  xdg.configFile."konveyor/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/konveyor/config.kdl";

  # ── shortcuts ────────────────────────────────────────────────────
  # Konveyor takes the keys its binds need away from Plasma by itself, so this
  # only re-homes what that displaced: vim Mod+L is focus-right, and Meta+L was
  # Lock Screen. Meta+Backspace is the lock key the old niri config used.
  programs.plasma.shortcuts.ksmserver."Lock Session" = [ "Meta+Backspace" "Screensaver" ];
  # KWin 6.7 ships Meta+Backspace as "Restore Window" too, and of two actions
  # on one key only the first to register fires, so locking was a coin toss.
  programs.plasma.shortcuts.kwin."Window Restore" = [ ];

  # Region screenshot on the key most people's hands already know; Print still
  # opens Spectacle as before. Meta+T (title bars) is pkgs/titlebar-toggle's,
  # registered by the script itself.
  programs.plasma.spectacle.shortcuts.captureRectangularRegion = "Meta+Shift+S";

  # Konveyor's Mod+. (expel a window from its column) took the emoji picker's
  # Meta+. — it moves next door.
  programs.plasma.shortcuts."services/org.kde.plasma.emojier.desktop"._launch = "Meta+;";

  # The desktop half of the Hyprland/i3-style keymap in config/konveyor/config.kdl:
  # Meta+V there floats a window, so the clipboard history moves to Meta+Shift+V;
  # Meta+Shift+E is the i3/sway "exit" key, here KDE's log out / restart / shut down screen.
  programs.plasma.shortcuts.plasmashell."show-on-mouse-pos" = "Meta+Shift+V";
  programs.plasma.shortcuts.ksmserver."Log Out" = [ "Ctrl+Alt+Del" "Meta+Shift+E" ];

  # ── sleep: match laptop.nix ──────────────────────────────────────
  # PowerDevil holds logind's lid inhibitor while Plasma runs, so laptop.nix's
  # HandleLidSwitch=suspend-then-hibernate only applies at the greeter. This is
  # the in-session equivalent; it calls logind's SuspendThenHibernate, so
  # laptop.nix's HibernateDelaySec (30min) still sets the delay.
  #
  # The power profile is chosen per power source too. Left unset, PowerDevil
  # keeps whatever was last picked (Meta+B used to cycle it), and t14 sat in
  # power-saver on AC — the CPU held back while plugged in, felt as lag
  # everywhere. Performance on AC means more fan; "balanced" if that bothers.
  programs.plasma.powerdevil = lib.mapAttrs (_: powerProfile: {
    whenSleepingEnter = "standbyThenHibernate";
    inherit powerProfile;
  }) {
    AC         = "performance";
    battery    = "balanced";
    lowBattery = "powerSaving";
  };

  # ── speed ────────────────────────────────────────────────────────
  # Baloo indexes file NAMES only, and not ~/Projects. Content indexing had
  # crawled into a WordPress backup's image cache: 5.4 GB of index, 40% of a
  # core and ~6 GB of RAM, for full-text search nothing here uses. KRunner and
  # Dolphin still find files by name; projects are reached by tmux-sessionizer
  # and fzf, which never needed an index. After changing this, `balooctl6 purge`
  # drops the old index and rebuilds it under these rules.
  programs.plasma.configFile.baloofilerc.General = {
    "only basic indexing" = true;
    "exclude folders"     = "${config.home.homeDirectory}/Projects/";
  };

  # Every Plasma/KWin animation at half length: the UI feels quicker without
  # losing the motion that shows where a window went. 0 turns them off.
  programs.plasma.configFile.kdeglobals.KDE.AnimationDurationFactor = 0.5;

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
    "text/plain"                = "org.kde.kate.desktop";
    "application/pdf"           = "org.kde.okular.desktop";
  };
}
