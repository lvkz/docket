import QtQuick
import QtQuick.Controls
import "CalendarModel.js" as Model

Popup {
    id: root
    required property var theme
    required property var backend
    required property var calendars
    // the window's events, to look up fields the views' copies drop (e.g. "repeats")
    required property var events
    signal editRequested(var event)

    property var event: ({})
    property bool confirmDelete: false
    readonly property var normalized: Model.normalizedEvent(event)
    readonly property var calendar: calendars.find(c => c.id === event.calendarId) || ({})
    readonly property bool editable: !!event.uid && calendar.readonly === false && !event.repeats

    function show(value) {
        event = events.find(e => e.id === value.id) || value;
        confirmDelete = false;
        backend.error = "";
        open();
    }

    Connections {
        target: root.backend
        function onWritten() { root.close(); }
    }
    function whenText(e) {
        const start = Model.dateFromKey(Model.eventDateKey(e));
        const day = Model.WEEKDAY_NAMES[start.getDay()] + ", " + Model.MONTH_NAMES[start.getMonth()] + " " + start.getDate();
        if (e.allDay) return day + " · All day";
        return day + " · " + Model.formatTime(e.start, false, "24h") + "–" + Model.formatTime(e.end, false, "24h");
    }

    anchors.centerIn: Overlay.overlay
    width: Math.min(520, parent.width - 40)
    modal: true
    padding: 20
    background: Rectangle { color: root.theme.background; border.color: root.theme.border; radius: 6 }

    contentItem: Column {
        spacing: 10
        Text {
            width: parent.width
            text: root.event.title || ""
            wrapMode: Text.Wrap
            color: root.theme.foreground
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize + 4
            font.bold: true
        }
        Text {
            text: root.event.start ? root.whenText(root.event) + (root.event.repeats ? " · repeats" : "") : ""
            color: root.theme.foreground
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize
        }
        Row {
            spacing: 8
            Rectangle {
                width: 10; height: 10; radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: root.theme.calendarColor(root.event.calendarColor)
            }
            Text {
                text: root.event.calendarName || ""
                color: root.theme.muted
                font.family: root.theme.family
                font.pixelSize: root.theme.fontSize
            }
        }
        Text {
            visible: !!root.event.location
            width: parent.width
            text: "📍 " + (root.event.location || "")
            wrapMode: Text.Wrap
            color: root.theme.foreground
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize
        }
        Chip {
            visible: root.normalized.meetingUrl !== ""
            theme: root.theme
            active: true
            text: "Join " + (Model.meetingProviderLabel(root.normalized.meetingProvider) || "meeting")
            onClicked: Qt.openUrlExternally(root.normalized.meetingUrl)
        }
        ScrollView {
            visible: !!root.event.description
            width: parent.width
            height: Math.min(220, description.implicitHeight)
            TextEdit {
                id: description
                width: root.availableWidth
                text: root.event.description || ""
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                color: root.theme.muted
                selectionColor: root.theme.selected
                font.family: root.theme.family
                font.pixelSize: root.theme.fontSize - 1
            }
        }
        Text {
            visible: !root.editable && !!root.event.uid
            width: parent.width
            wrapMode: Text.Wrap
            text: root.calendar.readonly ? "Read-only calendar"
                : root.event.repeats ? "Repeating event: edit or delete it in Google Calendar or iCloud" : ""
            color: root.theme.muted
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize - 2
        }
        Text {
            visible: root.backend.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: root.backend.error
            color: root.theme.urgent
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize - 1
        }
        Row {
            visible: root.editable
            spacing: 8
            Chip {
                theme: root.theme
                text: "Edit"
                onClicked: { root.close(); root.editRequested(root.event); }
            }
            Chip {
                theme: root.theme
                text: root.confirmDelete ? "Click again to delete" : "Delete"
                active: root.confirmDelete
                onClicked: {
                    if (root.confirmDelete) root.backend.remove(root.event);
                    else root.confirmDelete = true;
                }
            }
        }
    }
}
