// Konveyor's workspaces as one row of numbers in the top bar: the current one
// is a wider highlighted pill, workspaces with windows on them are bright and
// empty ones faded. Click a number to go there; scroll over the row to step
// through them.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    // No hover tooltip: the numbers are the whole story.
    toolTipMainText: ""
    toolTipSubText: ""

    // KWin's virtual desktops, which Konveyor keeps in step with its workspaces.
    TaskManager.VirtualDesktopInfo { id: desktops }

    // Every window everywhere, only to tell occupied workspaces from empty ones.
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        onCountChanged: root.updateOccupied()
        onDataChanged: root.updateOccupied()
    }

    // Desktop id → true, for each desktop with a window of its own on it
    // (windows pinned to all workspaces, like picture-in-picture, don't count).
    property var occupied: ({})

    function updateOccupied() {
        const ids = {};
        for (let i = 0; i < tasks.count; i++) {
            const index = tasks.index(i, 0);
            if (tasks.data(index, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops)) {
                continue;
            }
            for (const id of tasks.data(index, TaskManager.AbstractTasksModel.VirtualDesktops) || []) {
                ids[id] = true;
            }
        }
        occupied = ids;
    }

    // Switching goes through KWin (desktops counted from 1), and Konveyor
    // follows it the same way it follows Mod+1..9.
    function kwin(member, args) {
        DBus.SessionBus.asyncCall({
            service: "org.kde.KWin",
            path: "/KWin",
            iface: "org.kde.KWin",
            member: member,
            arguments: args || [],
        });
    }

    fullRepresentation: RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth

        // One workspace per wheel notch; a touchpad's small steps add up to one.
        WheelHandler {
            property int pending: 0
            onWheel: event => {
                pending += event.angleDelta.y;
                for (; pending >= 120; pending -= 120) root.kwin("previousDesktop");
                for (; pending <= -120; pending += 120) root.kwin("nextDesktop");
            }
        }

        Repeater {
            model: desktops.desktopIds

            delegate: Rectangle {
                id: pill
                required property string modelData
                required property int index
                readonly property bool current: modelData === desktops.currentDesktop
                readonly property bool busy: root.occupied[modelData] === true
                readonly property color text: Kirigami.Theme.textColor

                Layout.alignment: Qt.AlignVCenter
                implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.1)
                implicitWidth: Math.round(implicitHeight * (current ? 1.8 : 1))
                radius: height / 2
                color: current ? Kirigami.Theme.highlightColor
                     : mouse.containsMouse ? Qt.rgba(text.r, text.g, text.b, 0.15)
                     : "transparent"
                Behavior on implicitWidth {
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: pill.index + 1
                    color: pill.current ? Kirigami.Theme.highlightedTextColor : pill.text
                    opacity: pill.current || pill.busy ? 1 : 0.45
                    font.bold: pill.current
                }

                // A MouseArea rather than HoverHandler: its hover clears on the
                // panel's leave event even when the pointer exits fast.
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.kwin("setCurrentDesktop", [new DBus.int32(pill.index + 1)])
                }
            }
        }
    }
}
