import QtQuick
import QtQuick.Controls
import "CalendarModel.js" as Model

// Mini month on top, the selected day's events in the middle, the calendar filter at the bottom.
Item {
    id: root
    required property var theme
    required property var events
    required property string selectedKey
    required property string todayKey
    required property var calendars
    required property var hiddenCalendars
    signal daySelected(string key)
    signal eventClicked(var event)
    signal eventHovered(string id)
    signal calendarToggled(string id, bool shown)

    // meetings with a Meet/Zoom/Teams link get a Join button from 15 min before until they end
    property date now: new Date()
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.now = new Date() }
    function joinable(event) {
        if (!event.meetingUrl || event.allDay) return false;
        const start = Date.parse(event.start), end = Date.parse(event.end);
        return now.getTime() >= start - 15 * 60000 && now.getTime() < end;
    }

    // the mini month browses on its own and follows the main view when it changes
    property int shownYear: Model.dateFromKey(selectedKey).getFullYear()
    property int shownMonth: Model.dateFromKey(selectedKey).getMonth()
    onSelectedKeyChanged: {
        const d = Model.dateFromKey(selectedKey);
        shownYear = d.getFullYear();
        shownMonth = d.getMonth();
    }
    function stepMonth(delta) {
        const next = Model.stepMonth(shownYear, shownMonth, delta);
        shownYear = next.year;
        shownMonth = next.month;
    }

    readonly property var weeks: Model.monthGrid(shownYear, shownMonth, 1, todayKey, {})
    readonly property real cell: Math.floor(width / 7)
    readonly property var dayEvents: Model.eventsForDay(Model.eventsByDay(events), selectedKey)
    readonly property var selectedDate: Model.dateFromKey(selectedKey)

    Column {
        id: mini
        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: 30
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Model.MONTH_NAMES[root.shownMonth] + " " + root.shownYear
                color: root.theme.foreground
                font.family: root.theme.family
                font.pixelSize: root.theme.fontSize + 1
                font.bold: true
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Chip { theme: root.theme; text: "‹"; onClicked: root.stepMonth(-1) }
                Chip { theme: root.theme; text: "›"; onClicked: root.stepMonth(1) }
            }
        }
        Row {
            Repeater {
                model: Model.weekdayOrder(1)
                delegate: Text {
                    required property int modelData
                    width: root.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: Model.WEEKDAY_NAMES[modelData].slice(0, 2)
                    color: root.theme.muted
                    font.family: root.theme.family
                    font.pixelSize: root.theme.fontSize - 2
                }
            }
        }
        Repeater {
            model: root.weeks
            delegate: Row {
                required property var modelData
                Repeater {
                    model: parent.modelData.days
                    delegate: Item {
                        id: day
                        required property var modelData
                        readonly property bool selected: modelData.key === root.selectedKey
                        width: root.cell
                        height: 30
                        Rectangle {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            radius: 13
                            color: day.modelData.today ? root.theme.accent
                                : dayMouse.containsMouse ? root.theme.selected : "transparent"
                            border.color: day.selected && !day.modelData.today ? root.theme.accent : "transparent"
                            border.width: 1
                        }
                        Text {
                            anchors.centerIn: parent
                            text: day.modelData.day
                            color: root.theme.foreground
                            opacity: day.modelData.inMonth ? 1 : 0.4
                            font.family: root.theme.family
                            font.pixelSize: root.theme.fontSize - 1
                            font.bold: day.modelData.today || day.selected
                        }
                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.daySelected(day.modelData.key)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: calendarsDivider
        anchors.bottom: filter.top
        anchors.bottomMargin: 10
        width: parent.width
        height: 1
        color: root.theme.border
    }

    // calendar filter: filled box = shown, outline = hidden (same setting as Settings → Calendars)
    Column {
        id: filter
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: 2
        Repeater {
            model: root.calendars
            delegate: Rectangle {
                id: calendarRow
                required property var modelData
                readonly property bool shown: root.hiddenCalendars.indexOf(modelData.id) < 0
                readonly property color tint: root.theme.calendarColor(modelData.calendarColor)
                width: filter.width
                height: 26
                radius: 4
                color: filterMouse.containsMouse ? root.theme.surface : "transparent"
                Rectangle {
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; radius: 3
                    color: calendarRow.shown ? calendarRow.tint : "transparent"
                    border.color: calendarRow.tint
                    border.width: 2
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Text {
                    x: 30
                    width: parent.width - 36
                    anchors.verticalCenter: parent.verticalCenter
                    text: calendarRow.modelData.calendarName
                    elide: Text.ElideRight
                    color: calendarRow.shown ? root.theme.foreground : root.theme.muted
                    font.family: root.theme.family
                    font.pixelSize: root.theme.fontSize - 1
                }
                MouseArea {
                    id: filterMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.calendarToggled(calendarRow.modelData.id, !calendarRow.shown)
                }
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: mini.bottom
        anchors.topMargin: 12
        width: parent.width
        height: 1
        color: root.theme.border
    }

    Text {
        id: dayTitle
        anchors.top: divider.bottom
        anchors.topMargin: 12
        text: (root.selectedKey === root.todayKey ? "Today · " : "")
            + Model.WEEKDAY_NAMES[root.selectedDate.getDay()] + ", "
            + Model.SHORT_MONTH_NAMES[root.selectedDate.getMonth()] + " " + root.selectedDate.getDate()
        color: root.selectedKey === root.todayKey ? root.theme.accent : root.theme.foreground
        font.family: root.theme.family
        font.pixelSize: root.theme.fontSize + 1
        font.bold: true
    }

    ListView {
        anchors.top: dayTitle.bottom
        anchors.topMargin: 10
        anchors.bottom: calendarsDivider.top
        anchors.bottomMargin: 10
        width: parent.width
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: root.dayEvents

        Text {
            visible: root.dayEvents.length === 0
            text: "Nothing scheduled"
            color: root.theme.muted
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize
        }

        delegate: Rectangle {
            id: row
            required property var modelData
            width: ListView.view.width
            height: details.implicitHeight + 12
            radius: 4
            color: rowMouse.containsMouse ? root.theme.selected : root.theme.surface
            opacity: Model.eventIsPast(modelData, new Date()) ? 0.55 : 1

            Rectangle {
                width: 3
                height: parent.height
                radius: 2
                color: root.theme.calendarColor(row.modelData.calendarColor)
            }
            Chip {
                id: join
                visible: root.joinable(row.modelData)
                z: 1
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                theme: root.theme
                active: true
                text: "Join"
                onClicked: Qt.openUrlExternally(row.modelData.meetingUrl)
            }
            Column {
                id: details
                x: 12
                y: 6
                width: parent.width - 20 - (join.visible ? join.width + 6 : 0)
                spacing: 2
                Text {
                    width: parent.width
                    text: row.modelData.title
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: root.theme.foreground
                    font.family: root.theme.family
                    font.pixelSize: root.theme.fontSize - 1
                }
                Text {
                    text: row.modelData.allDay ? "All day"
                        : Model.formatTime(row.modelData.start, false, "24h") + "–"
                          + Model.formatTime(row.modelData.end, false, "24h")
                    color: root.theme.muted
                    font.family: root.theme.family
                    font.pixelSize: root.theme.fontSize - 2
                }
                Text {
                    visible: !!row.modelData.location
                    width: parent.width
                    text: row.modelData.location
                    elide: Text.ElideRight
                    color: root.theme.muted
                    font.family: root.theme.family
                    font.pixelSize: root.theme.fontSize - 2
                }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: root.eventHovered(containsMouse ? row.modelData.id : "")
                cursorShape: Qt.PointingHandCursor
                onClicked: root.eventClicked(row.modelData)
            }
        }
    }
}
