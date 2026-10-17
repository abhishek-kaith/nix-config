{ runCommand, kdePackages }:

# The Plasma style (the bar, its popups, tooltips, OSDs): Breeze, in the
# colours of the current scheme, with one change. The mark Plasma puts on a
# bar item while its popup is open (the clock, a tray icon), and on the
# selected tab inside popups (the volume popup's Devices / Applications),
# is an accent box with 4px corners rather than Breeze's accent underline:
# the same shape as the current workspace's box (pkgs/workspace-indicator).
# Chosen in modules/home/plasma.nix.
#
# The bar's mark can't simply be switched off: it is the very SVG piece
# those popup tabs draw their selection with, so hiding it would leave the
# tabs with no visible selection.
#
# Rebuilt from the Breeze in this nixpkgs, so a Plasma update carries
# through. The theme holds only that one SVG (plus Breeze's plasmarc), and
# Plasma fills in everything else from Breeze ("default") itself.
let
  breeze = "${kdePackages.libplasma}/share/plasma/desktoptheme/default";
  # Part of the cache key Plasma keeps rendered SVG pieces under, so an edit
  # to the box is never served from a stale cache.
  version = "${kdePackages.libplasma.version}-${builtins.substring 0 8 (builtins.hashFile "sha256" ./active-tab.svg)}";
in
runCommand "plasma-style-breeze-boxed-${version}" { } ''
  theme=$out/share/plasma/desktoptheme/breeze-boxed
  mkdir -p $theme/widgets
  cp ${breeze}/plasmarc $theme/plasmarc

  cat > $theme/metadata.json <<'EOF'
  {
    "KPackageStructure": "Plasma/Theme",
    "KPlugin": {
      "Id": "breeze-boxed",
      "Name": "Breeze Boxed",
      "Description": "Breeze, with a rounded accent box for open popups and selected tabs",
      "License": "LGPL",
      "Version": "${version}",
      "EnabledByDefault": true
    },
    "X-Plasma-API": "5.0"
  }
  EOF

  # Breeze's tab bar with its nine north-active-tab frame pieces renamed out
  # of the way and the box's added. Breeze's margin hints for that prefix
  # stay, so tabs keep their padding.
  zcat ${breeze}/widgets/tabbar.svgz > tabbar.svg
  sed -i -E 's/id="(north-active-tab-(topleft|topright|top|left|center|right|bottomleft|bottomright|bottom))"/id="breeze-\1"/' tabbar.svg
  test "$(grep -o 'id="breeze-north-active-tab-' tabbar.svg | wc -l)" = 9   # Breeze changed: look again
  substituteInPlace tabbar.svg --replace-fail '</svg>' "$(cat ${./active-tab.svg})</svg>"
  gzip -9n < tabbar.svg > $theme/widgets/tabbar.svgz
''
