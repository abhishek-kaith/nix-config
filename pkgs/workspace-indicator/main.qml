// Konveyor's workspaces as one row of numbers in the top bar: an accent
// box sits behind the current one and slides when you switch, ones with
// windows are bright, empty ones faded. Click a number to go there; scroll
// over the row to step through them.
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

    fullRepresentation: Item {
        id: row

        // Every number gets the same small cell, so the box can slide from
        // one to the next and the row never shifts as you switch.
        readonly property int cellHeight: Math.round(digit.height + Kirigami.Units.smallSpacing)
        readonly property int cellWidth: Math.round(cellHeight * 1.3)
        readonly property int gap: Math.round(Kirigami.Units.smallSpacing / 2)
        readonly property int count: desktops.desktopIds.length
        readonly property int currentIndex: desktops.desktopIds.indexOf(desktops.currentDesktop)
        readonly property int duration: Kirigami.Units.longDuration

        implicitWidth: count * cellWidth + Math.max(0, count - 1) * gap
        implicitHeight: cellHeight
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth

        // The numbers' font, measured once for the cell size.
        TextMetrics {
            id: digit
            font.pointSize: 7   // level with the clock
            font.weight: Font.DemiBold
            text: "8"
        }

        // One workspace per wheel notch; a touchpad's small steps add up to one.
        WheelHandler {
            property int pending: 0
            onWheel: event => {
                pending += event.angleDelta.y;
                for (; pending >= 120; pending -= 120) root.kwin("previousDesktop");
                for (; pending <= -120; pending += 120) root.kwin("nextDesktop");
            }
        }

        // The current workspace: a small accent box behind its number, its
        // corners rounded a little, not into a pill.
        Rectangle {
            visible: row.currentIndex >= 0
            x: row.currentIndex * (row.cellWidth + row.gap)
            anchors.verticalCenter: parent.verticalCenter
            width: row.cellWidth
            height: row.cellHeight
            radius: Math.round(height / 4)
            color: Kirigami.Theme.highlightColor
            Behavior on x {
                NumberAnimation { duration: row.duration; easing.type: Easing.OutCubic }
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: row.gap

            Repeater {
                model: desktops.desktopIds

                // A MouseArea rather than HoverHandler: its hover clears on the
                // panel's leave event even when the pointer exits fast.
                delegate: MouseArea {
                    id: cell
                    required property string modelData
                    required property int index
                    readonly property bool current: index === row.currentIndex
                    readonly property bool busy: root.occupied[modelData] === true

                    width: row.cellWidth
                    height: row.cellHeight
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.kwin("setCurrentDesktop", [new DBus.int32(index + 1)])

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: cell.index + 1
                        font.pointSize: digit.font.pointSize
                        font.weight: cell.current ? Font.DemiBold : Font.Medium
                        color: cell.current ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                        opacity: cell.current || cell.busy || cell.containsMouse ? 1 : 0.4
                        Behavior on color {
                            ColorAnimation { duration: row.duration }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: Kirigami.Units.shortDuration }
                        }
                    }
                }
            }
        }
    }
}
