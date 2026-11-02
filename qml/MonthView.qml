import QtQuick
import "CalendarModel.js" as Model

Item {
    id: root
    required property var theme
    required property var events
    required property string selectedKey
    required property string todayKey
    property string highlightId: ""
    signal eventClicked(var event)
    signal dayClicked(string key)

    readonly property var selected: Model.dateFromKey(selectedKey)
    readonly property var grouped: Model.eventsByDay(events)
    readonly property var weeks: Model.monthGrid(selected.getFullYear(), selected.getMonth(), 1, todayKey, grouped)
    readonly property real cellWidth: width / 7
    readonly property real cellHeight: (height - header.height) / 6
    // room for the day number (26px) and a "+N more" line (16px)
    readonly property int previewCount: Math.max(0, Math.floor((cellHeight - 26 - 16) / 20))

    Row {
        id: header
        Repeater {
            model: Model.weekdayOrder(1)
            delegate: Text {
                required property int modelData
                width: root.cellWidth
                height: 26
                horizontalAlignment: Text.AlignHCenter
                text: Model.WEEKDAY_NAMES[modelData].slice(0, 3)
                color: root.theme.muted
                font.family: root.theme.family
                font.pixelSize: root.theme.fontSize
            }
        }
    }

    Column {
        anchors.top: header.bottom
        Repeater {
            model: root.weeks
            delegate: Row {
                required property var modelData
                Repeater {
                    model: parent.modelData.days
                    delegate: Rectangle {
                        id: cell
                        required property var modelData
                        readonly property var dayEvents: Model.eventsForDay(root.grouped, modelData.key)
                        width: root.cellWidth
                        height: root.cellHeight
                        color: cellMouse.containsMouse ? root.theme.surface : "transparent"
                        border.color: root.theme.border
                        border.width: 0.5
                        opacity: modelData.inMonth ? 1 : 0.45

                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.dayClicked(cell.modelData.key)
                        }
                        Rectangle {
                            x: 4
                            y: 3
                            width: 22
                            height: 20
                            radius: 10
                            color: cell.modelData.today ? root.theme.accent : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: cell.modelData.day
                                color: root.theme.foreground
                                font.family: root.theme.family
                                font.pixelSize: root.theme.fontSize - 1
                                font.bold: cell.modelData.today
                            }
                        }
                        Column {
                            x: 3
                            y: 25
                            spacing: 2
                            Repeater {
                                model: cell.dayEvents.slice(0, root.previewCount)
                                delegate: EventBlock {
                                    required property var modelData
                                    event: modelData
                                    theme: root.theme
                                    highlightId: root.highlightId
                                    compact: true
                                    width: cell.width - 6
                                    height: 18
                                    onClicked: event => root.eventClicked(event)
                                }
                            }
                            Text {
                                visible: cell.dayEvents.length > root.previewCount
                                text: "+" + (cell.dayEvents.length - root.previewCount) + " more"
                                color: root.theme.muted
                                font.family: root.theme.family
                                font.pixelSize: root.theme.fontSize - 3
                            }
                        }
                    }
                }
            }
        }
    }
}
