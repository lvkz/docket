import QtQuick

// The month title, with ‹ › around it when the window is too narrow for the toolbar's own
// (clicking the title then goes to today).
Row {
    id: root
    required property var theme
    required property string title
    property bool navigation: false
    signal stepped(int delta)
    signal todayClicked()

    spacing: 12
    Chip {
        visible: root.navigation
        theme: root.theme
        text: "‹"
        onClicked: root.stepped(-1)
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: root.theme.foreground
        font.family: root.theme.family
        font.pixelSize: root.theme.fontSize + 4
        font.bold: true
        MouseArea {
            anchors.fill: parent
            enabled: root.navigation
            cursorShape: root.navigation ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.todayClicked()
        }
    }
    Chip {
        visible: root.navigation
        theme: root.theme
        text: "›"
        onClicked: root.stepped(1)
    }
}
