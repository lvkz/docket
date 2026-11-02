import QtQuick
import QtQuick.Controls

Button {
    id: control
    required property var theme
    property bool active: false
    // a single Nerd Font glyph: square button, and the font's Mono variant, whose icons fit
    // their cell (the regular variant draws them wider, so they sit off-center)
    property bool iconOnly: false

    flat: true
    focusPolicy: Qt.NoFocus
    padding: 6
    leftPadding: 12
    rightPadding: 12
    // icon buttons keep the height of a text button (so rows line up) and are square
    implicitHeight: iconOnly ? Math.ceil(textMetrics.height) + topPadding + bottomPadding
        : implicitContentHeight + topPadding + bottomPadding
    implicitWidth: iconOnly ? implicitHeight : implicitContentWidth + leftPadding + rightPadding
    font.family: iconOnly ? "CaskaydiaMono Nerd Font Mono" : theme.family
    font.pixelSize: iconOnly ? theme.fontSize + 8 : theme.fontSize

    FontMetrics { id: textMetrics; font.family: control.theme.family; font.pixelSize: control.theme.fontSize }

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
