import QtQuick
import QtQuick.Controls

Button {
    id: control
    required property var theme
    property bool active: false

    flat: true
    focusPolicy: Qt.NoFocus
    padding: 6
    leftPadding: 12
    rightPadding: 12
    font.family: theme.family
    font.pixelSize: theme.fontSize

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? control.theme.foreground : control.theme.muted
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 4
        color: control.active ? control.theme.accent
            : control.hovered ? control.theme.selected : control.theme.surface
        border.color: control.theme.border
        border.width: 1
    }
}
