// Run with tests/run. The edit form's calendar picker, offscreen, against a fake backend.
import QtQuick
import QtQuick.Controls
import QtTest
import "../qml"

Item {
    id: window
    width: 900
    height: 800

    QtObject {
        id: fakeTheme
        readonly property string family: "monospace"
        readonly property int fontSize: 13
        readonly property color background: "#101820"
        readonly property color foreground: "#e0e0e0"
        readonly property color muted: "#808080"
        readonly property color accent: "#4080c0"
        readonly property color urgent: "#c04040"
        readonly property color border: "#303840"
        readonly property color surface: "#182028"
        readonly property color selected: "#203040"
        function calendarColor(name) { return "#4080c0"; }
    }
    QtObject {
        id: fakeBackend
        property string error: ""
        property var sent: null
        signal written()
        function update(payload) { sent = payload; }
        function create(payload) { sent = payload; }
    }

    EventForm {
        id: form
        theme: fakeTheme
        backend: fakeBackend
        calendars: [
            { id: "mine", calendarName: "Mine", readonly: false },
            { id: "shared", calendarName: "Shared", readonly: true },
            { id: "other", calendarName: "Other", readonly: false },
        ]
    }

    TestCase {
        name: "EventFormCalendar"
        when: windowShown

        readonly property var standup: ({
            id: "s", uid: "s", title: "Standup", calendarId: "other", allDay: false, repeats: true,
            start: "2026-11-04T10:00:00-05:00", end: "2026-11-04T11:00:00-05:00",
            location: "", description: "",
        })

        function init() { fakeBackend.sent = null; }
        function cleanup() { form.close(); }

        // the calendar picker: the ComboBox listing the writable calendars
        function picker(item) {
            item = item || form.contentItem;
            for (let i = 0; i < item.children.length; ++i) {
                const child = item.children[i];
                if (child instanceof ComboBox && child.model && child.model[0] === "Mine") return child;
                const found = picker(child);
                if (found) return found;
            }
            return null;
        }

        function test_edit_starts_on_the_events_calendar() {
            form.edit(standup, "all");
            compare(picker().currentIndex, 1);  // "Other"; the read-only calendar isn't offered
            form.submit();
            compare(fakeBackend.sent.calendar, "other");
            compare(fakeBackend.sent.moveTo, "other");
        }

        function test_picking_another_calendar_moves_it() {
            form.edit(standup, "all");
            picker().currentIndex = 0;
            form.submit();
            compare(fakeBackend.sent.calendar, "other");
            compare(fakeBackend.sent.moveTo, "mine");
            compare(fakeBackend.sent.scope, "all");
        }

        function test_one_occurrence_cannot_change_calendar() {
            form.edit(standup, "this");
            verify(!picker().enabled);
            form.edit(standup, "all");
            verify(picker().enabled);
        }
    }
}
