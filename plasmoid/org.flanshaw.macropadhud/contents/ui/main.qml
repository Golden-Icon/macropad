import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore

Item {
    id: root

    // Entry points for macropad-status/-cycle/-manager. plasmashell's shell
    // PATH may not include ~/.local/bin, so use an explicit tilde path.
    readonly property string statusCmd: "~/.local/bin/macropad-status"
    readonly property string cycleCmd: "~/.local/bin/macropad-cycle"
    readonly property string managerCmd: "~/.local/bin/macropad-manager"
    readonly property int pollInterval: 1500

    readonly property var knobSlots: ["knob_cw", "knob_press", "knob_ccw"]

    property var profiles: []
    property int activeIndex: -1
    property var activeLabels: ({})
    property var activeBindings: ({})

    readonly property string activeName: {
        const p = profiles[activeIndex]
        return p ? p.name.toUpperCase() : "NO PROFILES"
    }

    Layout.preferredWidth: hud.implicitWidth
    Layout.preferredHeight: hud.implicitHeight
    Layout.margins: PlasmaCore.Units.smallSpacing

    // Poll: the executable engine runs the command every `pollInterval` ms and
    // reports the output through newData. ParsedJSON is small and cheap.
    PlasmaCore.DataSource {
        id: runner
        engine: "executable"
        onNewData: (sourceName, data) => {
            if (sourceName === root.statusCmd && data.stdout) {
                const snap = JSON.parse(data.stdout)
                root.profiles = snap.profiles
                root.activeIndex = snap.active_index
                const active = root.profiles[root.activeIndex]
                root.activeLabels = active?.labels ?? {}
                root.activeBindings = active?.bindings ?? {}
            }
        }
    }

    Component.onCompleted: runner.connectSource(statusCmd, pollInterval)

    function run(cmd) {
        runner.connectSource(cmd, 0)
    }

    RowLayout {
        id: hud
        spacing: PlasmaCore.Units.largeSpacing

        // ---- left: profile name + 3x2 keycaps + knob ----
        ColumnLayout {
            spacing: PlasmaCore.Units.smallSpacing

            Text {
                text: root.activeName
                font.bold: true
                font.pointSize: Math.round(PlasmaCore.Theme.defaultFont.pointSize * 1.1)
                color: PlasmaCore.Theme.textColor
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                spacing: PlasmaCore.Units.smallSpacing

                ColumnLayout {
                    spacing: PlasmaCore.Units.smallSpacing
                    RowLayout {
                        spacing: PlasmaCore.Units.smallSpacing
                        Keycap { slot: "button1" }
                        Keycap { slot: "button2" }
                        Keycap { slot: "button3" }
                    }
                    RowLayout {
                        spacing: PlasmaCore.Units.smallSpacing
                        Keycap { slot: "button4" }
                        Keycap { slot: "button5" }
                        Keycap { slot: "button6" }
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: PlasmaCore.Theme.viewBorderColor
                }

                ColumnLayout {
                    spacing: PlasmaCore.Units.smallSpacing
                    KnobCap { slot: "knob_ccw"; title: "CCW" }
                    KnobCap { slot: "knob_press"; title: "PRESS" }
                    KnobCap { slot: "knob_cw"; title: "CW" }
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: PlasmaCore.Theme.viewBorderColor
        }

        // ---- right: profile list + gear ----
        ColumnLayout {
            spacing: PlasmaCore.Units.smallSpacing

            RowLayout {
                spacing: PlasmaCore.Units.smallSpacing

                Text {
                    text: "PROFILES"
                    font.family: PlasmaCore.Theme.defaultFont.family
                    font.pointSize: PlasmaCore.Theme.defaultFont.pointSize
                    font.bold: true
                    color: PlasmaCore.Theme.textColor
                    Layout.fillWidth: true
                }

                Item {
                    Layout.preferredWidth: PlasmaCore.Units.iconSizes.small
                    Layout.preferredHeight: PlasmaCore.Units.iconSizes.small
                    PlasmaCore.IconItem {
                        source: "emblem-system-symbolic"
                        anchors.fill: parent
                        active: gearArea.containsMouse
                    }
                    MouseArea {
                        id: gearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.run(managerCmd)
                    }
                }
            }

            Repeater {
                model: root.profiles
                delegate: Item {
                    required property var modelData
                    Layout.preferredWidth: row.implicitWidth + PlasmaCore.Units.smallSpacing * 2
                    Layout.preferredHeight: row.implicitHeight

                    MouseArea {
                        id: row
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.run(root.cycleCmd + " --set " + modelData.file)
                        RowLayout {
                            spacing: PlasmaCore.Units.smallSpacing
                            Text {
                                text: modelData.name
                                font.family: PlasmaCore.Theme.defaultFont.family
                                font.pointSize: PlasmaCore.Theme.defaultFont.pointSize
                                font.bold: root.activeIndex === index
                                color: row.containsMouse
                                       ? PlasmaCore.Theme.highlightColor
                                       : PlasmaCore.Theme.textColor
                            }
                            Text {
                                text: root.activeIndex === index ? "\u25CF" : ""
                                color: PlasmaCore.Theme.highlightColor
                            }
                        }
                    }
                }
            }
        }
    }

    component Keycap: Rectangle {
        id: cap
        required property string slot
        property string titleText: "BTN"

        // Friendly label wins when present; the raw binding sits beneath it.
        readonly property string lbl: root.activeLabels[slot] ?? ""
        readonly property string bnd: root.activeBindings[slot] ?? ""
        readonly property string main: lbl || bnd || "\u2014"

        Layout.preferredWidth: PlasmaCore.Units.gridUnit * 4
        Layout.preferredHeight: PlasmaCore.Units.gridUnit * 2.4
        radius: PlasmaCore.Units.smallSpacing
        color: PlasmaCore.Theme.viewBackgroundColor
        border.color: PlasmaCore.Theme.viewBorderColor
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: PlasmaCore.Units.tinySpacing
            spacing: 0

            Text {
                text: cap.main
                font.family: PlasmaCore.Theme.defaultFont.family
                font.pointSize: PlasmaCore.Theme.defaultFont.pointSize
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: PlasmaCore.Theme.textColor
            }
            Text {
                text: cap.lbl ? cap.bnd : ""
                font: PlasmaCore.Theme.smallestFont
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: PlasmaCore.Theme.textColor
                opacity: 0.7
            }
        }
    }

    component KnobCap: Rectangle {
        id: knobcap
        required property string slot
        required property string title

        // A single knob is drawn once; first knob action with a label wins.
        readonly property string lbl: {
            for (let s of root.knobSlots) {
                if (root.activeLabels[s]) return root.activeLabels[s]
            }
            return ""
        }
        readonly property string bnd: root.activeBindings[slot] ?? ""
        readonly property string main: knobcap.lbl || bnd || "\u2014"

        Layout.preferredWidth: PlasmaCore.Units.gridUnit * 3.2
        Layout.preferredHeight: PlasmaCore.Units.gridUnit * 1.9
        radius: PlasmaCore.Units.smallSpacing
        color: PlasmaCore.Theme.highlightColor
        opacity: 0.9
        border.color: PlasmaCore.Theme.highlightColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: PlasmaCore.Units.tinySpacing
            spacing: 0
            Text {
                text: knobcap.title
                font: PlasmaCore.Theme.smallestFont
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                color: PlasmaCore.Theme.highlightedTextColor
                opacity: 0.8
            }
            Text {
                text: knobcap.main
                font.family: PlasmaCore.Theme.defaultFont.family
                font.pointSize: PlasmaCore.Theme.defaultFont.pointSize
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: PlasmaCore.Theme.highlightedTextColor
            }
        }
    }
}