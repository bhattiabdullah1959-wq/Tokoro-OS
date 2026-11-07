import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string tierTool: "/usr/libexec/tokoro/tokoro-tier"
    readonly property var tiers: [
        "ultra-performance",
        "performance",
        "balanced",
        "quality",
        "ultra-quality"
    ]

    property string tier: "balanced"
    property string recommended: ""
    property bool warning: false

    function refresh() {
        stateSource.connectSource(root.tierTool + " status");
    }

    function runCommand(command) {
        actionSource.connectSource(command);
    }

    Plasmoid.toolTipMainText: "Tokoro OS — " + root.tier
    Plasmoid.toolTipSubText: root.warning
        ? "Above the hardware recommendation" + (root.recommended ? " (" + root.recommended + ")" : "")
        : (root.recommended ? "Hardware recommends " + root.recommended : "Hardware not detected yet")

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    compactRepresentation: Item {
        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            source: root.warning ? "dialog-warning" : "preferences-system-performance"
            active: compactMouse.containsMouse
        }
        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 17
        Layout.preferredHeight: Kirigami.Units.gridUnit * 15
        collapseMarginsHint: true

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: "Performance tier"
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: root.warning ? "dialog-warning" : "dialog-information"
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: root.warning
                        ? "Above recommendation (" + root.recommended + ")"
                        : (root.recommended ? "Recommended: " + root.recommended : "Not detected")
                    opacity: root.warning ? 1 : 0.8
                }
            }

            Repeater {
                model: root.tiers
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text: modelData.replace("-", " ")
                    checkable: true
                    checked: root.tier === modelData
                    onClicked: root.runCommand(root.tierTool + " set " + modelData)
                }
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: "Re-detect hardware"
                onClicked: root.runCommand(root.tierTool + " detect --save")
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: "Work / Gaming toggle"
                onClicked: root.runCommand("/usr/bin/tokoro mode toggle")
            }
        }
    }

    PlasmaCore.DataSource {
        id: stateSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            try {
                var state = JSON.parse(data.stdout || "{}");
                root.tier = state.tier || root.tier;
                root.recommended = state.recommended || "";
                root.warning = state.above_recommendation === true;
            } catch (error) {
                // Leave the previous values; the tool is available on every image.
            }
            stateSource.disconnectSource(sourceName);
        }
    }

    PlasmaCore.DataSource {
        id: actionSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            actionSource.disconnectSource(sourceName);
            root.refresh();
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
