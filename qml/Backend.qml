import QtQuick
import Quickshell
import Quickshell.Io

// Runs bin/docket-helper and exposes its JSON as properties.
Item {
    id: root

    readonly property string helper: Quickshell.shellDir + "/../bin/docket-helper"
    property var events: []
    property var calendars: []
    property string error: ""
    property bool syncing: false
    property string rangeFrom: ""
    property string rangeTo: ""
    // {id, start, end} of an event just dragged: the window shows it there until the save
    // and the reload after it finish (or the save fails), so it doesn't jump back meanwhile
    property var pendingEvent: null

    // a create/update/delete went through
    signal written()

    function load(from, to) {
        rangeFrom = from;
        rangeTo = to;
        reload();
    }
    function reload() {
        if (!rangeFrom) return;
        if (eventsProc.running) { eventsProc.pending = true; return; }
        eventsProc.command = [helper, "events", rangeFrom, rangeTo];
        eventsProc.running = true;
    }
    function sync() {
        if (syncProc.running) return;
        syncing = true;
        syncProc.running = true;
    }
    property var searchResults: []
    property string searchedFor: ""
    function search(query) {
        searchProc.pendingQuery = query;
        if (searchProc.running) return;
        searchProc.command = [helper, "search", query];
        searchProc.query = query;
        searchProc.running = true;
    }
    // organizer and attendees of the event shown in the details popup
    property var people: ({ organizer: null, attendees: [] })
    function loadPeople(event) {
        people = { organizer: null, attendees: [] };
        peopleProc.wanted = JSON.stringify([event.calendarId, event.uid]);
        if (!peopleProc.running) peopleProc.start();
    }
    function create(event) { write("create", "Creating event", event); }
    function update(event) { write("update", "Saving event", event); }
    function remove(event, scope) {
        write("delete", "Deleting event", { calendar: event.calendarId, uid: event.uid, scope: scope, occurrence: event.start });
    }
    function write(command, what, payload) {
        if (writeProc.running) return;
        writeProc.what = what;
        writeProc.command = [helper, command, JSON.stringify(payload)];
        writeProc.running = true;
    }
    function parse(text, what) {
        try {
            const payload = JSON.parse(text);
            if (!payload.ok) error = what + ": " + payload.error;
            return payload.ok ? payload : null;
        } catch (e) {
            error = what + ": no response from docket-helper";
            return null;
        }
    }

    Process {
        id: eventsProc
        property bool pending: false
        stdout: StdioCollector {
            onStreamFinished: {
                const payload = root.parse(text, "Loading events");
                if (payload) { root.events = payload.events; root.error = ""; }
                if (!writeProc.running) root.pendingEvent = null;
            }
        }
        onExited: if (pending) { pending = false; root.reload(); }
    }
    Process {
        id: calendarsProc
        running: true
        command: [root.helper, "calendars"]
        stdout: StdioCollector {
            onStreamFinished: {
                const payload = root.parse(text, "Loading calendars");
                if (payload) root.calendars = payload.calendars;
            }
        }
    }
    Process {
        id: syncProc
        command: [root.helper, "sync"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.syncing = false;
                if (root.parse(text, "Sync")) root.reload();
            }
        }
    }
    Process {
        id: searchProc
        property string query: ""
        property string pendingQuery: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const payload = root.parse(text, "Search");
                root.searchResults = payload ? payload.events : [];
                root.searchedFor = searchProc.query;
            }
        }
        // typing while a search runs: run once more with the latest text
        onExited: if (pendingQuery !== query) root.search(pendingQuery)
    }
    Process {
        id: writeProc
        property string what: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.parse(text, writeProc.what)) { root.error = ""; root.written(); root.reload(); }
                else root.pendingEvent = null;
            }
        }
    }
    Process {
        id: peopleProc
        // JSON [calendar, uid] last asked for, and the one this run is loading
        property string wanted: ""
        property string loading: ""
        function start() {
            loading = wanted;
            command = [root.helper, "people"].concat(JSON.parse(wanted));
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const payload = root.parse(text, "Loading attendees");
                if (payload && peopleProc.loading === peopleProc.wanted)
                    root.people = { organizer: payload.organizer, attendees: payload.attendees };
            }
        }
        // another event was opened while this ran: load that one
        onExited: if (loading !== wanted) start()
    }
    // vdirsyncer's own timer syncs every 30 min; pick up its changes
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.reload()
    }
}
