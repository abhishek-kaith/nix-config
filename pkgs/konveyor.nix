{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  jq,
  python3,
  kdePackages,
  libxcb,
  xcbutilwm,
}:

# Konveyor — scrolling-column tiling for Plasma, niri-style, as a native KWin
# effect plugin (C++). Not in nixpkgs. Upstream's ./install.sh builds against
# the running KWin and copies into /usr, neither of which exists here; a
# derivation does the same build against the exact KWin in this nixpkgs, which
# is the property that installer goes to great lengths to get.
#
# Bump: change `rev` to a newer commit, set `hash = lib.fakeHash;`, build, and
# paste the hash nix prints. Upstream has no releases or tags yet.
stdenv.mkDerivation {
  pname = "konveyor";
  version = "0.1.0-unstable-2026-10-12";

  src = fetchFromGitHub {
    owner = "DevL0rd";
    repo = "Konveyor";
    rev = "d7955832f460ad1e4d90dbd4344c4aef85d7590b";
    hash = "sha256-O0ThBDoNJZb0sItKqcedziBbbOqsjy5T3NPABqj0iZk=";
  };

  postPatch = ''
    # Every target builds with -Werror. Upstream tracks one compiler; nixpkgs
    # bumps gcc on its own schedule, and a new warning must not become a
    # failed rebuild of the desktop.
    find . -name CMakeLists.txt -exec sed -i 's/ -Werror//' {} +

    # The effect ships EnabledByDefault=false, and the installer flips it on
    # with kwriteconfig6. KWin falls back to this metadata when kwinrc says
    # nothing, so flipping the default here means it is on at first login with
    # nothing written to kwinrc — and turning it off in System Settings still
    # sticks, because that writes an explicit false.
    m=src/effect/plugin/metadata.json
    jq '.KPlugin.EnabledByDefault = true' "$m" > "$m.tmp"
    mv "$m.tmp" "$m"
  '';

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    jq
    kdePackages.extra-cmake-modules
    kdePackages.wrapQtAppsHook
  ];

  buildInputs = with kdePackages; [
    qtbase
    qtdeclarative
    kwin
    kdecoration
    kcoreaddons
    kglobalaccel
    kconfig
    kcolorscheme
    knotifications
    ki18n
    kservice
    kwindowsystem
    kcmutils
    libplasma
    libxcb
    xcbutilwm

    # bin/konveyor-cheatsheet (Mod+/) is a Python script that asks the running
    # effect for its binds over D-Bus. Its `#!/usr/bin/env python3` has no
    # dbus module on NixOS, so the cheatsheet died on its first import. Being
    # in buildInputs is what lets fixup's patchShebangs point it at this one.
    (python3.withPackages (ps: [ ps.dbus-python ]))
  ];

  # The unit tests want a nested KWin session; the build itself is the check
  # that matters here (it fails loudly on a KWin API change).
  cmakeFlags = [ (lib.cmakeBool "KONVEYOR_BUILD_TESTS" false) ];

  meta = {
    description = "Scrolling column tiling for KDE Plasma (KWin effect)";
    homepage = "https://github.com/DevL0rd/Konveyor";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
