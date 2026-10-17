// Title bars start hidden; Meta+T shows or hides them on every window at once.
// The state is not saved: each login starts hidden again.
let hidden = true;

function apply(window) {
    // Only server-side decorations can be removed. Apps that draw their own
    // title bar (GTK, Chromium, Zen with its title bar off) keep theirs.
    if (window.normalWindow) {
        window.noBorder = hidden;
    }
}

workspace.windowList().forEach(apply);
workspace.windowAdded.connect(apply);

registerShortcut("Toggle Title Bars", "Toggle title bars on all windows", "Meta+T", function () {
    hidden = !hidden;
    workspace.windowList().forEach(apply);
});
