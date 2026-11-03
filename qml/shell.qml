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
    // width of the week view's hour labels, shared so the toolbar can center on the day columns
    readonly property int weekGutter: 56
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

    // week view: 3 days from the selected one when 7 columns would be narrower than 110px
    // (window margins 32, sidebar 260 + 20 when shown, hour labels)
    readonly property bool threeDay:
        (window.width - 32 - (window.width >= 960 ? 280 : 0) - weekGutter) / 7 < 110
    readonly property var weekDays: {
        const selected = Model.dateFromKey(selectedKey);
        if (!threeDay) return Model.daysForView(selectedKey, "week", 1);
        return [0, 1, 2].map(i => new Date(selected.getFullYear(), selected.getMonth(), selected.getDate() + i));
    }
    readonly property var range: {
        const selected = Model.dateFromKey(selectedKey);
        let first, days;
        if (view === "agenda") { first = selected; days = agendaDays; }
        else if (view === "week") { first = weekDays[0]; days = weekDays.length; }
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
        const month = date => Model.MONTH_NAMES[date.getMonth()];
        if (view === "week") {
            // days that cross months name both: "October – November 2026"
            const first = weekDays[0], last = weekDays[weekDays.length - 1];
            if (first.getMonth() !== last.getMonth())
                return month(first) + (first.getFullYear() !== last.getFullYear() ? " " + first.getFullYear() : "")
                    + " – " + month(last) + " " + last.getFullYear();
        }
        return month(d) + " " + d.getFullYear();
    }
    onRangeChanged: backend.load(range.from, range.to)

    function step(delta) {
        const d = Model.dateFromKey(selectedKey);
        const next = view === "month" ? new Date(d.getFullYear(), d.getMonth() + delta, 1)
            : new Date(d.getFullYear(), d.getMonth(), d.getDate() + (view === "week" && threeDay ? 3 : 7) * delta);
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

            // three zones: where you are (title) | how you look at it (views) | actions
            Item {
                id: toolbar
                width: parent.width
                height: newButton.height
                // lines up with the sidebar below: Today on its left edge, + New on its right
                // (no ‹ › there: the sidebar calendar sits right below). Without the sidebar:
                // Today ‹ › + New, and Today and ‹ › hide only when they'd run into the view
                // switcher (t and ←/→ still work then).
                readonly property bool wide: window.width >= 960
                readonly property real fullLeftWidth: todayButton.implicitWidth + navButtons.implicitWidth
                    + newButton.implicitWidth + 16
                readonly property bool compactLeft: !wide
                    && fullLeftWidth + 8 + (titleText.visible ? 120 : 0) > viewSwitch.centered - 16
                Item {
                    id: leftGroup
                    width: toolbar.wide ? 272 : toolbar.compactLeft ? newButton.width : toolbar.fullLeftWidth
                    height: parent.height
                    Chip {
                        id: todayButton
                        visible: !toolbar.compactLeft
                        theme: appTheme
                        text: "Today"
                        ToolTip.visible: hovered
                        ToolTip.text: "Today (t)"
                        onClicked: root.selectedKey = root.todayKey
                    }
                    Row {
                        id: navButtons
                        visible: !toolbar.wide && !toolbar.compactLeft
                        anchors.right: newButton.left
                        anchors.rightMargin: 8
                        spacing: 4
                        Chip {
                            theme: appTheme
                            text: "‹"
                            ToolTip.visible: hovered
                            ToolTip.text: root.view === "month" ? "Previous month (←)"
                                : root.view === "week" && root.threeDay ? "Previous 3 days (←)" : "Previous week (←)"
                            onClicked: root.step(-1)
                        }
                        Chip {
                            theme: appTheme
                            text: "›"
                            ToolTip.visible: hovered
                            ToolTip.text: root.view === "month" ? "Next month (→)"
                                : root.view === "week" && root.threeDay ? "Next 3 days (→)" : "Next week (→)"
                            onClicked: root.step(1)
                        }
                    }
                    Chip {
                        id: newButton
                        anchors.right: parent.right
                        anchors.rightMargin: toolbar.wide ? 12 : 0
                        theme: appTheme
                        text: "+ New"
                        active: true
                        onClicked: form.start(root.selectedKey)
                    }
                }
                Text {
                    id: titleText
                    // week view: here when wide, centered above the day columns when narrow
                    visible: root.view !== "week" || toolbar.wide
                    x: leftGroup.width + 8
                    width: viewSwitch.x - x - 16
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
                // centered on the same axis as the content below (in week view: the day
                // columns, like the month title); slides aside on narrow windows rather
                // than overlap + New, the title, or the actions
                Rectangle {
                    id: viewSwitch
                    readonly property real areaStart: leftGroup.width + 8
                    readonly property real contentLeft: (sidebar.visible ? sidebar.width + 20 : 0)
                        + (root.view === "week" ? root.weekGutter : 0)
                    readonly property real centered: contentLeft + (toolbar.width - contentLeft - width) / 2
                    x: Math.max(areaStart + (titleText.visible ? 120 : 0), Math.min(centered, actions.x - width - 16))
                    width: viewRow.width
                    height: parent.height
                    radius: 4
                    color: appTheme.surface
                    border.color: appTheme.border
                    clip: true
                    Row {
                        id: viewRow
                        height: parent.height
                        Repeater {
                            model: ["agenda", "week", "month"]
                            delegate: Rectangle {
                                id: segment
                                required property string modelData
                                required property int index
                                readonly property bool current: root.view === modelData
                                width: segmentLabel.implicitWidth + 28
                                height: viewRow.height
                                radius: 4
                                color: current ? appTheme.accent : segmentMouse.containsMouse ? appTheme.selected : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                // divider between segments
                                Rectangle {
                                    visible: segment.index > 0
                                    width: 1
                                    height: parent.height - 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: appTheme.border
                                }
                                Text {
                                    id: segmentLabel
                                    anchors.centerIn: parent
                                    text: segment.modelData[0].toUpperCase() + segment.modelData.slice(1)
                                    color: appTheme.foreground
                                    font.family: appTheme.family
                                    font.pixelSize: appTheme.fontSize
                                    font.bold: segment.current
                                }
                                MouseArea {
                                    id: segmentMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.view = segment.modelData
                                }
                            }
                        }
                    }
                }
                Row {
                    id: actions
                    anchors.right: parent.right
                    spacing: 8
                    // Nerd Font icons (magnifier, refresh); labels live in the tooltips
                    Chip {
                        theme: appTheme
                        text: "\uf002"
                        iconOnly: true
                        ToolTip.visible: hovered
                        ToolTip.text: "Search (/)"
                        onClicked: search.start()
                    }
                    Chip {
                        theme: appTheme
                        text: "\uf021"
                        iconOnly: true
                        enabled: !backend.syncing
                        ToolTip.visible: hovered
                        ToolTip.text: backend.syncing ? "Syncing…" : "Sync (r)"
                        onClicked: backend.sync()
                    }
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
                title: toolbar.wide ? "" : root.title
                gutter: root.weekGutter
                days: root.weekDays.map(d => Model.keyForDate(d))
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
            onEditRequested: (event, scope) => form.edit(event, scope)
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
