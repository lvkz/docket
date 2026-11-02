import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Copied from tether-quickshell: follows the active Omarchy theme.
    readonly property string themePath: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme"
    readonly property string overridePath: Quickshell.env("HOME") + "/.config/omarchy/shell.toml"
    readonly property string family: "monospace"
    property var colors: ({})
    property var shell: ({})
    property var overrides: ({})
    readonly property color background: colors.background || colors.color0 || system.window
    readonly property color foreground: colors.foreground || colors.color7 || system.windowText
    readonly property color accent: colors.accent || colors.color4 || system.highlight
    readonly property color urgent: colors.urgent || colors.red || colors.color1 || system.windowText
    readonly property color surface: Qt.tint(background, Qt.rgba(foreground.r, foreground.g, foreground.b, 0.045))
    readonly property color selected: Qt.tint(background, Qt.rgba(accent.r, accent.g, accent.b, 0.16))
    readonly property color border: Qt.tint(background, Qt.rgba(foreground.r, foreground.g, foreground.b, 0.22))
    readonly property color muted: Qt.tint(background, Qt.rgba(foreground.r, foreground.g, foreground.b, 0.68))
    readonly property int fontSize: Math.max(11, Math.min(20, Number(overrides["font.base-size"] || shell["font.base-size"] || 13)))
    readonly property SystemPalette system: SystemPalette { colorGroup: SystemPalette.Active }

    // khal calendar colors are terminal names ("light green", "dark red") or hex;
    // map names onto the theme palette so calendars follow the theme.
    // "intense_<key>" is the palette color with its saturation pushed up.
    function calendarColor(name) {
        const value = String(name || "").trim();
        if (/^#[0-9a-fA-F]{6}$/.test(value)) return value;
        if (value.startsWith("intense_")) return intense(calendarColor(value.slice(8)));
        if (derivedHues[value] !== undefined && !colors[value]) return derived(derivedHues[value]);
        const key = value.replace(/^light /, "bright_").replace(/^dark /, "").replace(/ /g, "_");
        return colors[key] || accent;
    }
    // colors most themes lack, made from a hue plus blue's saturation/lightness so they sit in the palette
    readonly property var derivedHues: ({ purple: 0.77, crimson: 0.99 })
    function derived(hue) {
        const blue = Qt.color(colors.blue || accent);
        return Qt.hsla(hue, Math.max(0.25, blue.hslSaturation), blue.hslLightness, 1);
    }
    function intense(base) {
        const c = Qt.color(base);
        return Qt.hsla(c.hslHue, Math.min(1, c.hslSaturation + 0.4), Math.max(0.35, Math.min(0.55, c.hslLightness)), 1);
    }

    // A deliberately narrow subset of public appearance TOML: palette hex colors
    // and sectioned numeric tokens. Unsupported values retain the system fallback.
    function parse(text) {
        const result = {};
        let section = "";
        for (const line of text.split("\n")) {
            const heading = line.match(/^\s*\[([\w-]+)\]\s*(?:#.*)?$/);
            if (heading) {
                section = heading[1] + ".";
                continue;
            }
            const entry = line.match(/^\s*([\w-]+)\s*=\s*(?:["'](#[0-9a-fA-F]{6})["']|([0-9]+(?:\.[0-9]+)?))\s*(?:#.*)?$/);
            if (entry) result[section + entry[1]] = entry[2] || entry[3];
        }
        return result;
    }

    readonly property FileView paletteFile: FileView {
        path: root.themePath + "/colors.toml"
        watchChanges: true
        printErrors: false
        onLoaded: root.colors = root.parse(text())
        onLoadFailed: root.colors = ({})
        onFileChanged: reload()
    }
    readonly property FileView shellFile: FileView {
        path: root.themePath + "/shell.toml"
        watchChanges: true
        printErrors: false
        onLoaded: root.shell = root.parse(text())
        onLoadFailed: root.shell = ({})
        onFileChanged: reload()
    }
    readonly property FileView overrideFile: FileView {
        path: root.overridePath
        watchChanges: true
        printErrors: false
        onLoaded: root.overrides = root.parse(text())
        onLoadFailed: root.overrides = ({})
        onFileChanged: reload()
    }
    // Reopen the public paths: a theme symlink replacement can leave a watcher
    // attached to its previous target. No shell process or directory scan needed.
    readonly property Timer themeRefresh: Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            root.paletteFile.reload();
            root.shellFile.reload();
            root.overrideFile.reload();
        }
    }
}
