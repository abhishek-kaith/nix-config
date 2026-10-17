{ symlinkJoin, tela-circle-icon-theme }:

# Tela-circle, the icon theme (chosen in modules/home/plasma.nix): every app
# a flat colour circle, a look of its own rather than macOS's rounded squares
# or Windows' tiles, and plain one-colour tray icons. Tela-circle-dark is
# drawn for dark mode and Tela-circle-light for light.
#
# With one fix for the top bar. Tela draws the icons Plasma's notifications
# entry uses (notification-inactive, -empty, -active, in several sizes) as a
# "!" in a circle, which reads as a warning sitting in the bar all day. Every
# copy is pointed at Tela's own bell instead, and its bell with a dot for
# unread notifications. Everything else is upstream, symlinked: symlinkJoin
# keeps the relative links the three variants share folders through, so a
# fix made once in Tela-circle reaches the other two.
symlinkJoin {
  name = "tela-circle-plasma-${tela-circle-icon-theme.version}";
  paths = [ tela-circle-icon-theme ];
  postBuild = ''
    bells=$out/share/icons/Tela-circle/24/panel
    test -e $bells/notification-symbolic.svg     # fail the build if Tela
    test -e $bells/notification-new-symbolic.svg # moves its bells
    find $out/share/icons -regex '.*/notification-\(inactive\|empty\)\(-symbolic\)?\.svg' \
      -exec ln -sf $bells/notification-symbolic.svg {} \;
    find $out/share/icons -regex '.*/notification-active\(-symbolic\)?\.svg' \
      -exec ln -sf $bells/notification-new-symbolic.svg {} \;
  '';
}
