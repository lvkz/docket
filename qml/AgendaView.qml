import QtQuick
import "CalendarModel.js" as Model

ListView {
    id: root
    required property var theme
    required property var events
    required property string fromKey
    required property string todayKey
    property string highlightId: ""
    required property int dayCount
    signal eventClicked(var event)

    // meetings with a Meet/Zoom/Teams link get a Join button from 15 min before until they end
    property date now: new Date()
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.now = new Date() }
    function joinable(event) {
        if (!event.meetingUrl || event.allDay) return false;
        const start = Date.parse(event.start), end = Date.parse(event.end);
        return now.getTime() >= start - 15 * 60000 && now.getTime() < end;
    }

    readonly property var days: {
        const grouped = Model.eventsByDay(events);
        const out = [];
        let key = fromKey;
        for (let i = 0; i < dayCount; i++) {
            if (grouped[key]) out.push({ key: key, events: grouped[key] });
            key = Model.nextDateKey(key);
        }
        return out;
    }

    clip: true
    spacing: 18
    model: days
    boundsBehavior: Flickable.StopAtBounds

    Text {
        visible: root.days.length === 0
        anchors.centerIn: parent
        text: "Nothing scheduled"
        color: root.theme.muted
        font.family: root.theme.family
        font.pixelSize: root.theme.fontSize + 2
    }

    delegate: Column {
        id: day
        required property var modelData
        width: ListView.view.width
        spacing: 6

        Text {
            readonly property var date: Model.dateFromKey(day.modelData.key)
            text: (day.modelData.key === root.todayKey ? "Today · " : "")
                + Model.WEEKDAY_NAMES[date.getDay()] + ", "
                + Model.MONTH_NAMES[date.getMonth()] + " " + date.getDate()
            color: day.modelData.key === root.todayKey ? root.theme.accent : root.theme.foreground
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize + 1
            font.bold: true
        }
        Repeater {
            model: day.modelData.events
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool past: Model.eventIsPast(modelData, new Date())
                width: day.width
                height: 46
                radius: 4
                readonly property bool highlighted: root.highlightId !== "" && modelData.id === root.highlightId
                color: mouse.containsMouse || highlighted ? root.theme.selected : root.theme.surface
                border.color: highlighted ? root.theme.calendarColor(modelData.calendarColor) : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                opacity: past ? 0.55 : 1

                Rectangle {
                    width: 4
                    height: parent.height
                    radius: 2
                    color: root.theme.calendarColor(row.modelData.calendarColor)
                }
                Text {
                    id: time
                    x: 16
                    width: 120
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.allDay ? "All day"
                        : Model.formatTime(row.modelData.start, false, "24h") + "–"
                          + Model.formatTime(row.modelData.end, false, "24h")
                    color: root.theme.muted
                    font.family: root.theme.family
                    font.pixelSize: root.theme.fontSize
                }
                Chip {
                    id: join
                    visible: root.joinable(row.modelData)
                    z: 1
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    theme: root.theme
                    active: true
                    text: "Join " + (Model.meetingProviderLabel(row.modelData.meetingProvider) || "")
                    onClicked: Qt.openUrlExternally(row.modelData.meetingUrl)
                }
                Column {
                    anchors.left: time.right
                    anchors.right: join.visible ? join.left : parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: row.modelData.title
                        elide: Text.ElideRight
                        color: root.theme.foreground
                        font.family: root.theme.family
                        font.pixelSize: root.theme.fontSize
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.calendarName
                            + (row.modelData.location ? " · " + row.modelData.location : "")
                        elide: Text.ElideRight
                        color: root.theme.muted
                        font.family: root.theme.family
                        font.pixelSize: root.theme.fontSize - 2
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.eventClicked(row.modelData)
                }
            }
        }
    }
}
