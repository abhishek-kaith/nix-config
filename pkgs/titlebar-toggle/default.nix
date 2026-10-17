{ runCommand }:

# A KWin script, not an effect: title bars hidden on every window by default,
# Meta+T brings them all back (and hides them again). The tiling has no use
# for them — Konveyor's focus ring marks the active window, and Meta+drag
# moves a window without one.
#
# EnabledByDefault in metadata.json is what turns it on, the same trick as
# pkgs/konveyor.nix: with nothing in kwinrc, KWin falls back to it, and
# switching it off in System Settings → Window Management → KWin Scripts still
# sticks. KWin 6.7 reads scripts from share/kwin-wayland/, not share/kwin/.
runCommand "kwin-titlebar-toggle" { } ''
  dir=$out/share/kwin-wayland/scripts/titlebar-toggle
  mkdir -p $dir/contents/code
  cp ${./metadata.json} $dir/metadata.json
  cp ${./main.js} $dir/contents/code/main.js
''
