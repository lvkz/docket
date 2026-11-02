import QtQuick
import "CalendarModel.js" as Model

Item {
    id: root
    required property var theme
    required property var events
    required property string selectedKey
    required property string todayKey
    property string highlightId: ""
    required property int dayStartHour
    required property int dayEndHour
    signal eventClicked(var event)
    signal dayClicked(string key)
    signal createAt(string key, int hour)

    readonly property int hourCount: dayEndHour - dayStartHour
    readonly property var days: Model.daysForView(selectedKey, "week", 1).map(d => Model.keyForDate(d))
    readonly property var grouped: Model.eventsByDay(events)
    readonly property int gutter: 56
    // stretch the day to the window; scroll only once hours would get shorter than 32px
    readonly property real hourHeight: Math.max(32, grid.height / hourCount)
    readonly property real colWidth: (width - gutter) / 7
    readonly property int allDayRows: Math.min(3, Math.max(0, ...days.map(k => Model.allDayEventsForDay(grouped, k).length)))
    property date now: new Date()

    Timer { interval: 60000; repeat: true; running: true; onTriggered: root.now = new Date() }

    Row {
        id: header
        x: root.gutter
        Repeater {
            model: root.days
            delegate: Text {
                required property string modelData
                readonly property var date: Model.dateFromKey(modelData)
                width: root.colWidth
                height: 28
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: Model.WEEKDAY_NAMES[date.getDay()].slice(0, 3) + " " + date.getDate()
                color: modelData === root.todayKey ? root.theme.accent : root.theme.foreground
                font.family: root.theme.family
                font.pixelSize: root.theme.fontSize
                font.bold: modelData === root.todayKey
                MouseArea { anchors.fill: parent; onClicked: root.dayClicked(parent.modelData) }
            }
        }
    }

    Row {
        id: allDay
        anchors.top: header.bottom
        x: root.gutter
        height: root.allDayRows * 22 + (root.allDayRows ? 4 : 0)
        Repeater {
            model: root.days
            delegate: Column {
                required property string modelData
                width: root.colWidth
                // explicit height: Row skips zero-height children, which shifted later days left
                height: allDay.height
                spacing: 2
                Repeater {
                    model: Model.allDayEventsForDay(root.grouped, parent.modelData).slice(0, 3)
                    delegate: EventBlock {
                        required property var modelData
                        event: modelData
                        width: root.colWidth - 4
                        height: 20
                        theme: root.theme
                        highlightId: root.highlightId
                        compact: true
                        onClicked: event => root.eventClicked(event)
                    }
                }
            }
        }
    }

    Flickable {
        id: grid
        anchors.top: allDay.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: root.hourCount * root.hourHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // when the grid scrolls, open it at 07:00
        Component.onCompleted: contentY = Math.max(0, Math.min(contentHeight - height, (7 - root.dayStartHour) * root.hourHeight))

        Repeater {
            model: root.hourCount
            delegate: Item {
                required property int index
                y: index * root.hourHeight
                width: grid.width
                height: root.hourHeight
                Rectangle { x: root.gutter; width: parent.width - root.gutter; height: 1; color: root.theme.border; opacity: 0.5 }
                Text {
                    width: root.gutter - 8
                    horizontalAlignment: Text.AlignRight
                    y: parent.index > 0 ? -height / 2 : 0
                    text: Model.pad2(root.dayStartHour + parent.index) + ":00"
                    color: root.theme.muted
                    font.family: root.theme.family
                    font.pixelSize: root.theme.fontSize - 2
                }
            }
        }
        Repeater {
            model: root.days
            delegate: Item {
                id: column
                required property string modelData
                required property int index
                x: root.gutter + index * root.colWidth
                width: root.colWidth
                height: grid.contentHeight
                Rectangle { width: 1; height: parent.height; color: root.theme.border; opacity: 0.5 }
                // double-click empty space: new event starting at that hour (events sit above and take their own clicks)
                MouseArea {
                    anchors.fill: parent
                    onDoubleClicked: mouse => root.createAt(column.modelData, Math.floor(mouse.y / root.hourHeight) + root.dayStartHour)
                }
                Repeater {
                    model: Model.layoutTimedEvents(root.grouped, column.modelData, root.dayStartHour, root.dayEndHour)
                    delegate: EventBlock {
                        required property var modelData
                        event: modelData.event
                        theme: root.theme
                        highlightId: root.highlightId
                        x: 2 + modelData.lane * (column.width - 4) / modelData.lanes
                        y: (modelData.startHour - root.dayStartHour) * root.hourHeight + 1
                        width: (column.width - 4) / modelData.lanes - 2
                        height: Math.max(18, (modelData.endHour - modelData.startHour) * root.hourHeight - 2)
                        onClicked: event => root.eventClicked(event)
                    }
                }
                Rectangle {
                    readonly property real hour: root.now.getHours() + root.now.getMinutes() / 60
                    visible: column.modelData === root.todayKey && hour >= root.dayStartHour && hour <= root.dayEndHour
                    y: (hour - root.dayStartHour) * root.hourHeight
                    width: parent.width
                    height: 2
                    color: root.theme.urgent
                }
            }
        }
    }
}
