{ runCommand }:

# A Plasma widget for the top bar (modules/home/plasma.nix): Konveyor's
# workspaces as one row of numbers — the current one highlighted, empty ones
# faded, click to switch, scroll to step through.
#
# Plasma's own pager can't do this here. It lays desktops out in KWin's grid
# rows, and Konveyor sets one row per workspace (its workspaces stack
# vertically), so the pager drew a column of tiny boxes in a 28px bar.
# kwinrc's Desktops/Rows doesn't help: Konveyor sets the rows again whenever
# a workspace is added or removed.
runCommand "plasma-workspace-indicator" { } ''
  dir=$out/share/plasma/plasmoids/workspace-indicator
  mkdir -p $dir/contents/ui
  cp ${./metadata.json} $dir/metadata.json
  cp ${./main.qml} $dir/contents/ui/main.qml
''
