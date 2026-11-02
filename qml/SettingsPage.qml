import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "CalendarModel.js" as Model

// Full-page settings: section list on the left, the chosen section on the right.
// Every change is written straight to ~/.config/docket/config.json through saved().
Item {
    id: root
    required property var theme
    required property var calendars
    required property int startHour
    required property int endHour
    required property var config
    required property int navWidth
    signal saved(var changes)

    property string section: "week"
    readonly property var sections: [
        { key: "week", title: "Week view" },
        { key: "calendars", title: "Calendars" },
        { key: "reminders", title: "Reminders" },
    ]
    // theme palette keys (the darker base colors), so a chosen color follows theme changes;
    // each also comes as "intense_<key>", a more saturated version
    readonly property var swatchKeys: ["red", "orange", "yellow", "green", "cyan", "crimson", "purple"]

    readonly property var calendarColors: config.calendarColors || {}
    readonly property var calendarNames: config.calendarNames || {}
    readonly property var hiddenCalendars: config.hiddenCalendars || []
    readonly property var reminderCalendarsOff: config.reminderCalendarsOff || []
    readonly property int reminderMinutes: Number.isInteger(config.reminderMinutes) ? config.reminderMinutes : 10

    // per-calendar map entry: empty value removes the override
    function setEntry(key, id, value) {
        const map = Object.assign({}, config[key] || {});
        if (value) map[id] = value;
        else delete map[id];
        saved({ [key]: map });
    }
    // per-calendar id list: present = setting applies
    function setListed(key, id, listed) {
        const list = (config[key] || []).filter(x => x !== id);
        if (listed) list.push(id);
        saved({ [key]: list });
    }

    component Heading: Text {
        color: root.theme.foreground
        font.family: root.theme.family
        font.pixelSize: root.theme.fontSize + 3
        font.bold: true
    }
    component Hint: Text {
        color: root.theme.muted
        wrapMode: Text.Wrap
        font.family: root.theme.family
        font.pixelSize: root.theme.fontSize - 1
    }
    component Toggle: CheckBox {
        id: toggle
        font.family: root.theme.family
        font.pixelSize: root.theme.fontSize - 1
        palette.base: root.theme.surface
        palette.text: root.theme.foreground
        palette.mid: root.theme.border
        contentItem: Text {
            leftPadding: toggle.indicator.width + 8
            text: toggle.text
            font: toggle.font
            color: toggle.enabled ? root.theme.foreground : root.theme.muted
            verticalAlignment: Text.AlignVCenter
        }
    }
    component HourBox: SpinBox {
        editable: true
        font.family: root.theme.family
        font.pixelSize: root.theme.fontSize
        textFromValue: value => Model.pad2(value) + ":00"
        valueFromText: text => parseInt(text, 10)
        palette.text: root.theme.foreground
        palette.base: root.theme.surface
        palette.button: root.theme.surface
        palette.buttonText: root.theme.foreground
        palette.mid: root.theme.border
    }

    Column {
        id: nav
        width: root.navWidth
        spacing: 4
        Repeater {
            model: root.sections
            delegate: Rectangle {
                id: navItem
                required property var modelData
                width: nav.width
                height: 36
                radius: 4
                color: root.section === modelData.key ? root.theme.selected
                    : navMouse.containsMouse ? root.theme.surface : "transparent"
                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: navItem.modelData.title
                    color: root.section === navItem.modelData.key ? root.theme.accent : root.theme.foreground
                    font.family: root.theme.family
                    font.pixelSize: root.theme.fontSize
                    font.bold: root.section === navItem.modelData.key
                }
                MouseArea {
                    id: navMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.section = navItem.modelData.key
                }
            }
        }
    }

    ScrollView {
        id: content
        anchors.left: nav.right
        anchors.leftMargin: 32
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        contentWidth: availableWidth

        // Week view
        ColumnLayout {
            visible: root.section === "week"
            width: Math.min(560, content.availableWidth)
            spacing: 12
            Heading { text: "Week view" }
            Hint { Layout.fillWidth: true; text: "Hours shown in the week grid. Events outside them still appear in Agenda and Month." }
            GridLayout {
                columns: 2
                columnSpacing: 12
                rowSpacing: 10
                Hint { text: "From" }
                HourBox {
                    id: fromBox
                    from: 0; to: 23
                    value: root.startHour
                    onValueModified: if (value < toBox.value) root.saved({ dayStartHour: value, dayEndHour: toBox.value })
                }
                Hint { text: "To" }
                HourBox {
                    id: toBox
                    from: 1; to: 24
                    value: root.endHour
                    onValueModified: if (fromBox.value < value) root.saved({ dayStartHour: fromBox.value, dayEndHour: value })
                }
            }
            Text {
                visible: fromBox.value >= toBox.value
                text: "The end has to be after the start — not saved"
                color: root.theme.urgent
                font.family: root.theme.family
                font.pixelSize: root.theme.fontSize - 1
            }
            Chip {
                theme: root.theme
                text: "Show the full day"
                onClicked: {
                    fromBox.value = 0;
                    toBox.value = 24;
                    root.saved({ dayStartHour: 0, dayEndHour: 24 });
                }
            }
        }

        // Calendars
        ColumnLayout {
            visible: root.section === "calendars"
            width: Math.min(720, content.availableWidth)
            spacing: 12
            Heading { text: "Calendars" }
            Hint {
                Layout.fillWidth: true
                text: "Rename, hide or recolor each calendar. An empty name and Default use what your khal config says."
            }
            Repeater {
                model: root.calendars
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    readonly property string chosen: root.calendarColors[modelData.id] || ""
                    Layout.fillWidth: true
                    implicitHeight: cardColumn.implicitHeight + 24
                    radius: 6
                    color: root.theme.surface
                    border.color: root.theme.border

                    ColumnLayout {
                        id: cardColumn
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 10
                        RowLayout {
                            spacing: 10
                            Rectangle {
                                width: 14; height: 14; radius: 7
                                color: root.theme.calendarColor(card.chosen || card.modelData.color)
                            }
                            TextField {
                                id: nameField
                                implicitWidth: 260
                                text: root.calendarNames[card.modelData.id] || ""
                                placeholderText: card.modelData.name
                                color: root.theme.foreground
                                placeholderTextColor: root.theme.muted
                                font.family: root.theme.family
                                font.pixelSize: root.theme.fontSize
                                font.bold: true
                                background: Rectangle {
                                    color: root.theme.background
                                    border.color: nameField.activeFocus ? root.theme.accent : root.theme.border
                                    radius: 4
                                }
                                onEditingFinished: if (text.trim() !== (root.calendarNames[card.modelData.id] || ""))
                                    root.setEntry("calendarNames", card.modelData.id, text.trim())
                            }
                            Text {
                                visible: card.modelData.readonly
                                text: "read-only"
                                color: root.theme.muted
                                font.family: root.theme.family
                                font.pixelSize: root.theme.fontSize - 2
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: card.modelData.id !== card.modelData.name
                            text: card.modelData.id
                            elide: Text.ElideMiddle
                            color: root.theme.muted
                            font.family: root.theme.family
                            font.pixelSize: root.theme.fontSize - 3
                        }
                        Toggle {
                            text: "Show in calendar"
                            checked: root.hiddenCalendars.indexOf(card.modelData.id) < 0
                            onToggled: root.setListed("hiddenCalendars", card.modelData.id, !checked)
                        }
                        RowLayout {
                            spacing: 12
                            Chip {
                                Layout.alignment: Qt.AlignTop
                                theme: root.theme
                                text: "Default"
                                active: card.chosen === ""
                                onClicked: root.setEntry("calendarColors", card.modelData.id, "")
                            }
                            Column {
                                spacing: 6
                                Repeater {
                                    model: [root.swatchKeys, root.swatchKeys.map(k => "intense_" + k)]
                                    delegate: Row {
                                        id: swatchRow
                                        required property var modelData
                                        spacing: 6
                                        Repeater {
                                            model: swatchRow.modelData
                                            delegate: Rectangle {
                                                id: swatch
                                                required property string modelData
                                                width: 28; height: 28; radius: 14
                                                color: root.theme.calendarColor(modelData)
                                                border.color: card.chosen === modelData ? root.theme.foreground : "transparent"
                                                border.width: 2
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.setEntry("calendarColors", card.modelData.id, swatch.modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            TextField {
                                id: hex
                                Layout.alignment: Qt.AlignTop
                                implicitWidth: 110
                                placeholderText: "#rrggbb"
                                text: card.chosen.startsWith("#") ? card.chosen : ""
                                color: root.theme.foreground
                                placeholderTextColor: root.theme.muted
                                font.family: root.theme.family
                                font.pixelSize: root.theme.fontSize - 1
                                validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{0,6}/ }
                                background: Rectangle {
                                    color: root.theme.background
                                    border.color: hex.activeFocus ? root.theme.accent : root.theme.border
                                    radius: 4
                                }
                                onAccepted: if (/^#[0-9a-fA-F]{6}$/.test(text)) root.setEntry("calendarColors", card.modelData.id, text)
                            }
                        }
                    }
                }
            }
        }

        // Reminders
        ColumnLayout {
            visible: root.section === "reminders"
            width: Math.min(560, content.availableWidth)
            spacing: 12
            Heading { text: "Reminders" }
            Hint {
                Layout.fillWidth: true
                text: "docket-notify sends a desktop notification before timed events. All-day events never notify. Changes apply within a minute."
            }
            Hint { text: "Remind me" }
            Row {
                spacing: 6
                Repeater {
                    model: [0, 5, 10, 15, 30]
                    delegate: Chip {
                        required property int modelData
                        theme: root.theme
                        text: modelData === 0 ? "Off" : modelData + " min before"
                        active: root.reminderMinutes === modelData
                        onClicked: root.saved({ reminderMinutes: modelData })
                    }
                }
            }
            Hint { Layout.topMargin: 8; text: "Calendars that send reminders" }
            Repeater {
                model: root.calendars
                delegate: Toggle {
                    required property var modelData
                    enabled: root.reminderMinutes > 0
                    text: modelData.calendarName
                    checked: root.reminderCalendarsOff.indexOf(modelData.id) < 0
                    onToggled: root.setListed("reminderCalendarsOff", modelData.id, !checked)
                }
            }
        }
    }
}
