import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "CalendarModel.js" as Model

Popup {
    id: root
    required property var theme
    required property var backend
    required property var calendars
    property string localError: ""
    // the event being edited, or null when creating
    property var editing: null
    // for a repeating event: "this" occurrence or "all" of them
    property string scope: ""
    property bool crossesMidnight: false
    readonly property var writable: calendars.filter(c => !c.readonly)
    readonly property var repeats: [
        { value: "", label: "Does not repeat" },
        { value: "daily", label: "Daily" },
        { value: "weekly", label: "Weekly" },
        { value: "monthly", label: "Monthly" },
        { value: "yearly", label: "Yearly" },
    ]

    // hour: start hour to prefill (double-click on the grid); omitted = next full hour
    // prefill from an existing event; repeat stays as it is
    function edit(event, editScope) {
        start(Model.eventDateKey(event));
        editing = event;
        scope = editScope;
        title.text = event.title;
        calendar.currentIndex = Math.max(0, writable.findIndex(c => c.id === event.calendarId));
        allDay.checked = event.allDay;
        if (event.allDay) {
            // stored end is exclusive; the form shows the last day
            const last = Model.dateFromKey(String(event.end).slice(0, 10));
            last.setDate(last.getDate() - 1);
            endDate.text = Model.keyForDate(last);
        } else {
            from.text = Model.formatTime(event.start, false, "24h");
            to.text = Model.formatTime(event.end, false, "24h");
            crossesMidnight = Model.localDateKeyFromIso(event.end) !== Model.eventDateKey(event);
        }
        location.text = event.location || "";
        description.text = event.description || "";
    }
    function start(dayKey, hour) {
        editing = null;
        crossesMidnight = false;
        const startHour = Number.isInteger(hour) && hour >= 0 ? Math.min(23, hour) : Math.min(22, new Date().getHours() + 1);
        title.text = "";
        location.text = "";
        description.text = "";
        date.text = dayKey;
        endDate.text = dayKey;
        allDay.checked = false;
        from.text = Model.pad2(startHour) + ":00";
        to.text = startHour === 23 ? "23:59" : Model.pad2(startHour + 1) + ":00";
        repeat.currentIndex = 0;
        until.text = "";
        localError = "";
        backend.error = "";
        open();
        title.forceActiveFocus();
    }
    function submit() {
        const dateOk = /^\d{4}-\d{2}-\d{2}$/;
        const timeOk = /^\d{1,2}:\d{2}$/;
        if (!title.text.trim()) { localError = "Add a title"; return; }
        if (editing && crossesMidnight && !allDay.checked) { localError = "This event crosses midnight; edit it in Google or iCloud for now"; return; }
        if (!dateOk.test(date.text) || (allDay.checked && !dateOk.test(endDate.text))) { localError = "Dates are YYYY-MM-DD"; return; }
        if (!allDay.checked && (!timeOk.test(from.text) || !timeOk.test(to.text))) { localError = "Times are HH:MM"; return; }
        if (until.text && !dateOk.test(until.text)) { localError = "The repeat end date is YYYY-MM-DD"; return; }
        localError = "";
        const pad = t => t.length === 4 ? "0" + t : t;
        const repeatValue = repeats[repeat.currentIndex].value;
        if (editing) {
            backend.update({
                calendar: editing.calendarId,
                moveTo: writable[calendar.currentIndex].id,
                uid: editing.uid,
                scope: scope,
                occurrence: editing.start,
                title: title.text.trim(),
                location: location.text.trim(),
                description: description.text.trim(),
                allDay: allDay.checked,
                start: allDay.checked ? date.text : date.text + "T" + pad(from.text),
                end: allDay.checked ? endDate.text : date.text + "T" + pad(to.text),
            });
            return;
        }
        backend.create({
            calendar: writable[calendar.currentIndex].id,
            title: title.text.trim(),
            location: location.text.trim(),
            description: description.text.trim(),
            allDay: allDay.checked,
            start: allDay.checked ? date.text : date.text + "T" + pad(from.text),
            end: allDay.checked ? endDate.text : date.text + "T" + pad(to.text),
            repeat: repeatValue,
            until: repeatValue ? until.text : "",
        });
    }

    Connections {
        target: root.backend
        function onWritten() { root.close(); }
    }

    anchors.centerIn: Overlay.overlay
    width: Math.min(480, parent.width - 40)
    modal: true
    padding: 20
    background: Rectangle { color: root.theme.background; border.color: root.theme.border; radius: 6 }

    component FormLabel: Text {
        color: root.theme.muted
        font.family: root.theme.family
        font.pixelSize: root.theme.fontSize - 1
    }
    component Field: TextField {
        Layout.fillWidth: true
        color: root.theme.foreground
        placeholderTextColor: root.theme.muted
        selectionColor: root.theme.selected
        font.family: root.theme.family
        font.pixelSize: root.theme.fontSize
        background: Rectangle { color: root.theme.surface; border.color: parent.activeFocus ? root.theme.accent : root.theme.border; radius: 4 }
        onAccepted: root.submit()
    }
    component Picker: ComboBox {
        id: picker
        Layout.fillWidth: true
        font.family: root.theme.family
        font.pixelSize: root.theme.fontSize
        contentItem: Text {
            leftPadding: 8
            text: picker.displayText
            font: picker.font
            color: root.theme.foreground
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle { color: root.theme.surface; border.color: root.theme.border; radius: 4 }
    }

    contentItem: GridLayout {
        columns: 2
        columnSpacing: 12
        rowSpacing: 10

        Text {
            Layout.columnSpan: 2
            text: !root.editing ? "New event" : root.scope === "this" ? "Edit this occurrence"
                : root.scope === "all" ? "Edit all occurrences" : "Edit event"
            color: root.theme.foreground
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize + 3
            font.bold: true
        }
        FormLabel { text: "Title" }
        Field { id: title; placeholderText: "What" }
        FormLabel { text: "Calendar" }
        // one occurrence of a repeating event can't move on its own
        Picker { id: calendar; enabled: root.scope !== "this" || !root.editing; model: root.writable.map(c => c.calendarName) }
        FormLabel { text: "Date" }
        Field { id: date; placeholderText: "YYYY-MM-DD" }
        FormLabel { text: "All day" }
        CheckBox { id: allDay; enabled: !(root.editing && root.editing.repeats) }
        FormLabel { text: allDay.checked ? "Last day" : "Time" }
        RowLayout {
            Layout.fillWidth: true
            Field { id: endDate; visible: allDay.checked; placeholderText: "YYYY-MM-DD" }
            Field { id: from; visible: !allDay.checked; placeholderText: "HH:MM" }
            Text { visible: !allDay.checked; text: "–"; color: root.theme.muted }
            Field { id: to; visible: !allDay.checked; placeholderText: "HH:MM" }
        }
        FormLabel { visible: !root.editing; text: "Repeat" }
        Picker { id: repeat; visible: !root.editing; model: root.repeats.map(r => r.label) }
        FormLabel { visible: !root.editing && repeat.currentIndex > 0; text: "Ends on" }
        Field { id: until; visible: !root.editing && repeat.currentIndex > 0; placeholderText: "YYYY-MM-DD, empty = never" }
        FormLabel { text: "Location" }
        Field { id: location; placeholderText: "Optional — a Meet/Zoom/Teams link adds a Join button" }
        FormLabel { Layout.alignment: Qt.AlignTop; text: "Notes" }
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            TextArea {
                id: description
                placeholderText: "Optional"
                wrapMode: TextArea.Wrap
                color: root.theme.foreground
                placeholderTextColor: root.theme.muted
                selectionColor: root.theme.selected
                font.family: root.theme.family
                font.pixelSize: root.theme.fontSize - 1
                background: Rectangle { color: root.theme.surface; border.color: description.activeFocus ? root.theme.accent : root.theme.border; radius: 4 }
            }
        }
        Text {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            visible: text !== ""
            text: root.localError || root.backend.error
            wrapMode: Text.Wrap
            color: root.theme.urgent
            font.family: root.theme.family
            font.pixelSize: root.theme.fontSize - 1
        }
        RowLayout {
            Layout.columnSpan: 2
            Layout.alignment: Qt.AlignRight
            Chip { theme: root.theme; text: "Cancel"; onClicked: root.close() }
            Chip { theme: root.theme; text: root.editing ? "Save" : "Create"; active: true; enabled: root.writable.length > 0; onClicked: root.submit() }
        }
    }
}
