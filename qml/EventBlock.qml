import QtQuick
import "CalendarModel.js" as Model

// One event drawn as a tinted block with a calendar-colored bar, used in week and month views.
Rectangle {
    id: root
    property var event: ({})
    required property var theme
    property bool compact: false
    // week grid: drag the body to move, the bottom edge to resize (pixel offsets on release)
    property bool movable: false
    readonly property bool dragging: mouse.dragging
    property real dragX: 0
    property real dragY: 0
    property real dragH: 0
    signal clicked(var event)
    signal moved(real dx, real dy)
    signal resized(real dy)

    readonly property color tint: theme.calendarColor(event.calendarColor)
    readonly property string startText: Model.formatTime(event.start, false, "24h")
    readonly property string rangeText: startText + "–" + Model.formatTime(event.end, false, "24h")
    // compact (month cells, all-day row): one line, start time only; week grid: title, then range
    readonly property string label: event.allDay ? event.title
        : compact ? startText + " " + event.title
        : height < 34 ? event.title + " · " + rangeText
        : event.title + "\n" + rangeText

    // set when the same event is hovered in the sidebar
    property string highlightId: ""
    readonly property bool highlighted: highlightId !== "" && event.id === highlightId

    radius: 3
    color: Qt.tint(theme.background, Qt.rgba(tint.r, tint.g, tint.b,
        highlighted ? 0.6 : mouse.containsMouse ? 0.45 : 0.28))
    border.color: highlighted ? tint : "transparent"
    border.width: highlighted ? 2 : 0
    z: dragging ? 2 : highlighted ? 1 : 0
    transform: Translate { x: root.dragX; y: root.dragY }
    clip: true
    opacity: highlighted ? 1 : Model.eventIsPast(event, new Date()) ? 0.6 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Rectangle {
        width: 3
        height: parent.height
        radius: 2
        color: root.tint
    }
    // week grid with room for two lines: title wraps above, range pinned below it
    readonly property bool twoLine: !compact && !event.allDay && height >= 34
    FontMetrics { id: titleMetrics; font: title.font }
    Column {
        anchors.fill: parent
        anchors.margins: 3
        anchors.leftMargin: 8
        spacing: 1
        Text {
            id: title
            width: parent.width
            text: root.twoLine ? root.event.title : root.label
            wrapMode: root.twoLine ? Text.Wrap : Text.NoWrap
            // as many title lines as fit above the range line
            maximumLineCount: root.twoLine ? Math.max(1, Math.floor((parent.height - range.implicitHeight - 1) / titleMetrics.height)) : 1
            elide: Text.ElideRight
            color: root.theme.foreground
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize - 2
            font.bold: root.twoLine
        }
        Text {
            id: range
            visible: root.twoLine
            width: parent.width
            text: root.rangeText
            elide: Text.ElideRight
            color: root.theme.muted
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize - 3
        }
    }
    MouseArea {
        id: mouse
        // scene coordinates: the block itself moves while dragged
        property point pressedAt
        property bool dragging: false
        property bool resizing: false
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: root.movable
        cursorShape: root.movable && (resizing || mouseY > height - 6) ? Qt.SizeVerCursor
            : dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onPressed: event => {
            pressedAt = mapToItem(null, event.x, event.y);
            dragging = false;
            resizing = root.movable && event.y > height - 6;
        }
        onPositionChanged: event => {
            if (!pressed || !root.movable) return;
            const at = mapToItem(null, event.x, event.y);
            const dx = at.x - pressedAt.x, dy = at.y - pressedAt.y;
            if (!dragging && Math.abs(dx) + Math.abs(dy) < 5) return;
            dragging = true;
            if (resizing) root.dragH = dy;
            else { root.dragX = dx; root.dragY = dy; }
        }
        onReleased: {
            if (dragging) {
                if (resizing) root.resized(root.dragH);
                else root.moved(root.dragX, root.dragY);
            }
            root.dragX = 0; root.dragY = 0; root.dragH = 0;
        }
        onClicked: if (!dragging) root.clicked(root.event)
    }
}
