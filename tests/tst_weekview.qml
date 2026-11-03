// Run: TZ=America/Toronto QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_weekview.qml
// Drags, resizes and clicks events in the real WeekView, offscreen, with fake events.
import QtQuick
import QtTest
import "../qml"

Item {
    id: window
    width: 1400
    height: 900

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
        function calendarColor(name) { return "#4080c0"; }
    }

    function event(id, title, start, end, calendarId) {
        return { id: id, uid: id, title: title, start: start, end: end, allDay: false,
                 calendarId: calendarId, calendarColor: "", location: "", description: "" };
    }

    WeekView {
        id: week
        anchors.fill: parent
        theme: fakeTheme
        selectedKey: "2026-11-04"
        todayKey: "2026-11-03"
        dayStartHour: 7
        dayEndHour: 20
        writableIds: ["mine"]
        events: [
            window.event("drag", "Drag me", "2026-11-04T10:00:00-05:00", "2026-11-04T11:00:00-05:00", "mine"),
            window.event("locked", "Locked", "2026-11-06T10:00:00-05:00", "2026-11-06T11:00:00-05:00", "shared"),
            window.event("late", "Late", "2026-11-07T19:00:00-05:00", "2026-11-08T01:00:00-05:00", "mine"),
        ]
    }

    SignalSpy { id: moved; target: week; signalName: "eventMoved" }
    SignalSpy { id: clicked; target: week; signalName: "eventClicked" }

    TestCase {
        name: "WeekViewDrag"
        when: windowShown

        function init() { moved.clear(); clicked.clear(); }

        // the block drawn for `title` (the first one, for events split across days)
        function block(title, item) {
            item = item || week;
            for (let i = 0; i < item.children.length; ++i) {
                const child = item.children[i];
                if (child.movable !== undefined && child.event && child.event.title === title) return child;
                const found = block(title, child);
                if (found) return found;
            }
            return null;
        }
        // press at (x, y) inside the block, move by (dx, dy) in steps, release; week coordinates
        // because the block itself moves while dragged
        function drag(title, x, y, dx, dy) {
            const b = block(title);
            verify(b, "no block for " + title);
            const at = b.mapToItem(week, x, y);
            mousePress(week, at.x, at.y);
            for (let step = 1; step <= 10; ++step)
                mouseMove(week, at.x + dx * step / 10, at.y + dy * step / 10);
            mouseRelease(week, at.x + dx, at.y + dy);
        }

        function test_move_to_next_day_and_hour_later() {
            drag("Drag me", 20, 20, week.colWidth, week.hourHeight);
            compare(moved.count, 1);
            compare(moved.signalArguments[0][1], "2026-11-05T11:00");
            compare(moved.signalArguments[0][2], "2026-11-05T12:00");
            compare(clicked.count, 0);
        }

        function test_move_snaps_to_quarter_hours() {
            drag("Drag me", 20, 20, 0, week.hourHeight * 0.3);  // 18 minutes
            compare(moved.signalArguments[0][1], "2026-11-04T10:15");
        }

        function test_resize_from_bottom_edge() {
            const b = block("Drag me");
            drag("Drag me", 20, b.height - 2, 0, week.hourHeight / 2);
            compare(moved.count, 1);
            compare(moved.signalArguments[0][1], "2026-11-04T10:00");
            compare(moved.signalArguments[0][2], "2026-11-04T11:30");
        }

        function test_resize_keeps_fifteen_minutes() {
            const b = block("Drag me");
            drag("Drag me", 20, b.height - 2, 0, -week.hourHeight * 3);
            compare(moved.signalArguments[0][2], "2026-11-04T10:15");
        }

        function test_click_and_jitter_open_details() {
            drag("Drag me", 20, 20, 2, 1);
            compare(moved.count, 0);
            compare(clicked.count, 1);
            compare(clicked.signalArguments[0][0].id, "drag");
        }

        function test_read_only_and_midnight_crossing_do_not_move() {
            verify(!block("Locked").movable);
            drag("Locked", 20, 20, week.colWidth, week.hourHeight);
            verify(!block("Late").movable);
            compare(moved.count, 0);
        }
    }
}
