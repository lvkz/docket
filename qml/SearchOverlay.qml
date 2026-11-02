import QtQuick
import QtQuick.Controls
import "CalendarModel.js" as Model

// "/" opens it: type to search all synced events, ↑/↓ to move, Enter to open.
Popup {
    id: root
    required property var theme
    required property var backend
    // the window's personalize(): applies calendar names/colors, returns null for hidden calendars
    required property var personalize
    signal picked(var event)

    readonly property var results: backend.searchResults.map(e => personalize(e)).filter(e => e)
    property int current: 0

    function start(text) {
        query.text = text || "";
        backend.searchResults = [];
        backend.searchedFor = "";
        current = 0;
        open();
        query.forceActiveFocus();
    }
    function choose(index) {
        if (index < 0 || index >= results.length) return;
        close();
        picked(results[index]);
    }

    x: (parent.width - width) / 2
    y: 60
    width: Math.min(640, parent.width - 40)
    height: Math.min(parent.height - 120, 72 + list.contentHeight + (hint.visible ? 30 : 0))
    modal: true
    padding: 12
    background: Rectangle { color: root.theme.background; border.color: root.theme.border; radius: 8 }

    Timer {
        id: debounce
        interval: 200
        onTriggered: root.backend.search(query.text)
    }

    contentItem: Item {
        TextField {
            id: query
            width: parent.width
            placeholderText: "Search events…"
            color: root.theme.foreground
            placeholderTextColor: root.theme.muted
            selectionColor: root.theme.selected
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize + 2
            background: Rectangle { color: root.theme.surface; border.color: root.theme.accent; radius: 6 }
            onTextChanged: { root.current = 0; debounce.restart(); }
            Keys.onDownPressed: root.current = Math.min(root.results.length - 1, root.current + 1)
            Keys.onUpPressed: root.current = Math.max(0, root.current - 1)
            onAccepted: root.choose(root.current)
        }
        Text {
            id: hint
            anchors.top: query.bottom
            anchors.topMargin: 10
            visible: root.results.length === 0
            text: query.text.trim().length < 2 ? "Type at least 2 characters"
                : root.backend.searchedFor === query.text ? "No events found" : "Searching…"
            color: root.theme.muted
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize - 1
        }
        ListView {
            id: list
            anchors.top: query.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            width: parent.width
            clip: true
            spacing: 2
            model: root.results
            currentIndex: root.current
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property var date: Model.dateFromKey(Model.eventDateKey(modelData))
                readonly property bool past: Model.eventIsPast(modelData, new Date())
                width: ListView.view.width
                height: 44
                radius: 4
                color: index === root.current ? root.theme.selected : rowMouse.containsMouse ? root.theme.surface : "transparent"

                Rectangle {
                    x: 4
                    width: 3
                    height: parent.height - 8
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 2
                    color: root.theme.calendarColor(row.modelData.calendarColor)
                }
                Column {
                    x: 16
                    width: parent.width - 32 - when.width
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: row.modelData.title + (row.modelData.repeats ? "  ⟳" : "")
                        elide: Text.ElideRight
                        color: row.past ? root.theme.muted : root.theme.foreground
                        font.family: root.theme.family
                        font.pixelSize: root.theme.fontSize
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.calendarName + (row.modelData.location ? " · " + row.modelData.location : "")
                        elide: Text.ElideRight
                        color: root.theme.muted
                        font.family: root.theme.family
                        font.pixelSize: root.theme.fontSize - 2
                    }
                }
                Text {
                    id: when
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: Model.SHORT_MONTH_NAMES[row.date.getMonth()] + " " + row.date.getDate()
                        + (row.date.getFullYear() !== new Date().getFullYear() ? " " + row.date.getFullYear() : "")
                        + "  " + (row.modelData.allDay ? "All day" : Model.formatTime(row.modelData.start, false, "24h"))
                    color: row.past ? root.theme.muted : root.theme.foreground
                    font.family: root.theme.family
                    font.pixelSize: root.theme.fontSize - 1
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.choose(row.index)
                }
            }
        }
    }
}
