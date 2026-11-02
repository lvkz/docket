//@ pragma AppId io.github.lvkz.Docket
//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "CalendarModel.js" as Model

ShellRoot {
    id: root

    property string view: "week"
    property string settingsSection: "week"
    // event under the pointer in the sidebar, highlighted in the main view
    property string hoveredEventId: ""
    property string selectedKey: todayKey
    property string todayKey: Model.keyForDate(new Date())
    readonly property int agendaDays: 21

    // ~/.config/docket/config.json, written by the Settings page (see README for the keys)
    property var config: ({})
    readonly property int dayStartHour: validHours ? config.dayStartHour : 0
    readonly property int dayEndHour: validHours ? config.dayEndHour : 24
    readonly property bool validHours: Number.isInteger(config.dayStartHour) && Number.isInteger(config.dayEndHour)
        && config.dayStartHour >= 0 && config.dayEndHour <= 24 && config.dayStartHour < config.dayEndHour
    function saveConfig(changes) {
        // FileView does not reload after its own write, so apply the change here too
        config = Object.assign({}, config, changes);
        configFile.setText(JSON.stringify(config, null, 2) + "\n");
    }
    FileView {
        id: configFile
        path: Quickshell.env("HOME") + "/.config/docket/config.json"
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            try { root.config = JSON.parse(text()); }
            catch (e) { root.config = {}; backend.error = "config.json is not valid JSON: " + e.message; }
        }
        onLoadFailed: root.config = {}
        onFileChanged: reload()
    }

    readonly property var range: {
        const selected = Model.dateFromKey(selectedKey);
        let first, days;
        if (view === "agenda") { first = selected; days = agendaDays; }
        else if (view === "week") { first = Model.startOfWeek(selected, 1); days = 7; }
        else { first = Model.startOfWeek(new Date(selected.getFullYear(), selected.getMonth(), 1), 1); days = 42; }
        const last = new Date(first.getFullYear(), first.getMonth(), first.getDate() + days);
        return { from: Model.keyForDate(first), to: Model.keyForDate(last) };
    }
    // khal events with the colors chosen in Settings → Calendars
    // Settings → Calendars: colors, names and hidden calendars applied on top of khal's data
    readonly property var calendarColors: config.calendarColors || {}
    readonly property var calendarNames: config.calendarNames || {}
    readonly property var hiddenCalendars: config.hiddenCalendars || []
    function personalize(item, id) {
        const changes = {};
        if (calendarColors[id]) changes.calendarColor = calendarColors[id];
        if (calendarNames[id]) changes.calendarName = calendarNames[id];
        return Object.keys(changes).length ? Object.assign({}, item, changes) : item;
    }
    // search results: personalized, or null when the calendar is hidden
    function visibleEvent(e) {
        return hiddenCalendars.indexOf(e.calendarId) < 0 ? personalize(e, e.calendarId) : null;
    }
    // open an event from search or a double-click: jump to its day, show its details
    function revealEvent(event) {
        if (view === "settings") view = "week";
        selectedKey = Model.eventDateKey(event);
        details.show(event);
    }
    readonly property var events: backend.events
        .filter(e => hiddenCalendars.indexOf(e.calendarId) < 0)
        .map(e => personalize(e, e.calendarId))
    // name/color here keep khal's values; calendarName/calendarColor carry the overrides
    readonly property var calendars: backend.calendars.map(c => Object.assign({}, c, {
        calendarName: calendarNames[c.id] || c.name,
        calendarColor: calendarColors[c.id] || c.color,
    }))

    readonly property string title: {
        if (view === "settings") return "Settings";
        const d = Model.dateFromKey(selectedKey);
        if (view === "month") return Model.MONTH_NAMES[d.getMonth()] + " " + d.getFullYear();
        if (view === "week") return Model.viewTitle(selectedKey, "week", 1);
        return "From " + Model.WEEKDAY_NAMES[d.getDay()] + ", " + Model.MONTH_NAMES[d.getMonth()] + " " + d.getDate();
    }
    onRangeChanged: backend.load(range.from, range.to)

    function step(delta) {
        const d = Model.dateFromKey(selectedKey);
        const next = view === "month" ? new Date(d.getFullYear(), d.getMonth() + delta, 1)
            : new Date(d.getFullYear(), d.getMonth(), d.getDate() + 7 * delta);
        selectedKey = Model.keyForDate(next);
    }
    function openDay(key) {
        selectedKey = key;
        view = "week";
    }
    function showWindow() {
        window.visible = true;
        focusProc.running = true;
    }

    Theme { id: appTheme }
    Backend { id: backend; Component.onCompleted: load(root.range.from, root.range.to) }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.todayKey = Model.keyForDate(new Date())
    }
    IpcHandler {
        target: "docket"
        function show(): void { root.showWindow(); }
        function view(name: string): void {
            if (["agenda", "week", "month"].indexOf(name) >= 0) root.view = name;
            root.showWindow();
        }
        function search(text: string): void { root.showWindow(); search.start(text); }
        function newEvent(): void { root.showWindow(); form.start(root.selectedKey); }
        function settings(section: string): void {
            if (section) root.settingsSection = section;
            root.view = "settings";
            root.showWindow();
        }
    }
    Process {
        id: focusProc
        command: ["hyprctl", "dispatch", "hl.dsp.focus({ window = 'pid:" + Quickshell.processId + "' })"]
    }
    Connections {
        target: Quickshell
        function onLastWindowClosed() { Qt.quit(); }
    }

    FloatingWindow {
        id: window
        title: "Docket"
        visible: true
        implicitWidth: 1100
        implicitHeight: 760
        minimumSize: Qt.size(640, 480)
        color: appTheme.background

        Item {
            anchors.fill: parent
            anchors.margins: 16
            focus: true
            Keys.onPressed: event => {
                if (form.opened || details.opened || search.opened) return;
                if (event.key === Qt.Key_Slash) { search.start(); event.accepted = true; return; }
                if (root.view === "settings") return;
                const keys = {
                    [Qt.Key_Left]: () => root.step(-1), [Qt.Key_Right]: () => root.step(1),
                    [Qt.Key_T]: () => root.selectedKey = root.todayKey,
                    [Qt.Key_A]: () => root.view = "agenda", [Qt.Key_W]: () => root.view = "week",
                    [Qt.Key_M]: () => root.view = "month", [Qt.Key_N]: () => form.start(root.selectedKey),
                    [Qt.Key_R]: () => backend.sync(),
                };
                if (keys[event.key]) { keys[event.key](); event.accepted = true; }
            }

            Row {
                id: toolbar
                width: parent.width
                spacing: 8
                // lines up with the sidebar below: Today on its left edge, + New on its right
                Item {
                    width: window.width >= 960 ? 272 : todayButton.width + newButton.width + 8
                    height: todayButton.height
                    Chip { id: todayButton; theme: appTheme; text: "Today"; onClicked: root.selectedKey = root.todayKey }
                    Chip {
                        id: newButton
                        anchors.right: parent.right
                        anchors.rightMargin: window.width >= 960 ? 12 : 0
                        theme: appTheme
                        text: "+ New"
                        active: true
                        onClicked: form.start(root.selectedKey)
                    }
                }
                Text {
                    width: toolbar.width - x - viewButtons.width - 8
                    height: parent.height
                    leftPadding: 12
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: root.title
                    color: appTheme.foreground
                    font.family: appTheme.family
                    font.pixelSize: appTheme.fontSize + 4
                    font.bold: true
                }
                Row {
                    id: viewButtons
                    spacing: 8
                    Chip { theme: appTheme; text: "Search  /"; onClicked: search.start() }
                    Repeater {
                        model: ["agenda", "week", "month"]
                        delegate: Chip {
                            required property string modelData
                            theme: appTheme
                            text: modelData[0].toUpperCase() + modelData.slice(1)
                            active: root.view === modelData
                            onClicked: root.view = modelData
                        }
                    }
                    Chip { theme: appTheme; text: backend.syncing ? "Syncing…" : "Sync"; enabled: !backend.syncing; onClicked: backend.sync() }
                    Chip { theme: appTheme; text: "Settings"; active: root.view === "settings"; onClicked: root.view = "settings" }
                }
            }

            Sidebar {
                id: sidebar
                anchors.top: toolbar.bottom
                anchors.topMargin: 16
                anchors.bottom: status.top
                anchors.bottomMargin: status.visible ? 8 : 0
                width: visible ? 260 : 0
                visible: window.width >= 960 && root.view !== "settings"
                theme: appTheme
                events: root.events
                selectedKey: root.selectedKey
                todayKey: root.todayKey
                onDaySelected: key => root.selectedKey = key
                onEventClicked: event => details.show(event)
                onEventHovered: id => root.hoveredEventId = id
                calendars: root.calendars
                hiddenCalendars: root.hiddenCalendars
                onCalendarToggled: (id, shown) => root.saveConfig({
                    hiddenCalendars: root.hiddenCalendars.filter(x => x !== id).concat(shown ? [] : [id])
                })
            }
            Loader {
                anchors.top: toolbar.bottom
                anchors.topMargin: 16
                anchors.left: sidebar.right
                anchors.leftMargin: sidebar.visible ? 20 : 0
                anchors.right: parent.right
                anchors.bottom: status.top
                anchors.bottomMargin: status.visible ? 8 : 0
                sourceComponent: root.view === "agenda" ? agenda : root.view === "week" ? week
                    : root.view === "month" ? month : settingsPage
            }
            Text {
                id: status
                anchors.bottom: parent.bottom
                width: parent.width
                visible: backend.error !== "" && !form.opened
                text: backend.error
                elide: Text.ElideRight
                color: appTheme.urgent
                font.family: appTheme.family
                font.pixelSize: appTheme.fontSize - 1
            }
        }

        Component {
            id: agenda
            AgendaView {
                highlightId: root.hoveredEventId
                theme: appTheme; events: root.events
                fromKey: root.selectedKey; todayKey: root.todayKey; dayCount: root.agendaDays
                onEventClicked: event => details.show(event)
            }
        }
        Component {
            id: week
            WeekView {
                highlightId: root.hoveredEventId
                theme: appTheme; events: root.events
                selectedKey: root.selectedKey; todayKey: root.todayKey
                dayStartHour: root.dayStartHour; dayEndHour: root.dayEndHour
                onEventClicked: event => details.show(event)
                onDayClicked: key => { root.selectedKey = key; root.view = "agenda"; }
                onCreateAt: (key, hour) => form.start(key, hour)
            }
        }
        Component {
            id: month
            MonthView {
                highlightId: root.hoveredEventId
                theme: appTheme; events: root.events
                selectedKey: root.selectedKey; todayKey: root.todayKey
                onEventClicked: event => details.show(event)
                onDayClicked: key => root.openDay(key)
            }
        }

        EventDetails {
            id: details
            theme: appTheme
            backend: backend
            calendars: root.calendars
            events: root.events
            onEditRequested: event => form.edit(event)
        }
        SearchOverlay {
            id: search
            theme: appTheme
            backend: backend
            personalize: root.visibleEvent
            onPicked: event => root.revealEvent(event)
        }
        EventForm { id: form; theme: appTheme; backend: backend; calendars: root.calendars }
        Component {
            id: settingsPage
            SettingsPage {
                theme: appTheme
                calendars: root.calendars
                startHour: root.dayStartHour
                endHour: root.dayEndHour
                config: root.config
                navWidth: 260
                section: root.settingsSection
                onSectionChanged: root.settingsSection = section
                onSaved: changes => root.saveConfig(changes)
            }
        }
    }
}
