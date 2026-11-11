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
    readonly property string aiTool: "/usr/libexec/tokoro/tokoro-ai"
    readonly property string driversTool: "/usr/libexec/tokoro/tokoro-drivers"
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

    // Setting a tier above the recommendation is allowed; it only needs a yes.
    property string pendingTier: ""

    property bool aiEnabled: false
    property string aiRuntime: "missing"
    property string aiCaps: ""
    property bool aiBusy: false
    property bool aiEnableRequested: false
    property bool rebootPrompt: false

    function refreshTier() {
        stateSource.connectSource(root.tierTool + " status");
    }

    // The AI probe runs python and curl, so it is polled far less often.
    function refreshAi() {
        aiSource.connectSource(root.aiTool + " status --json");
    }

    function refresh() {
        refreshTier();
        refreshAi();
    }

    function runCommand(command) {
        actionSource.connectSource(command);
    }

    function chooseTier(choice) {
        if (root.recommended !== ""
                && root.tiers.indexOf(choice) > root.tiers.indexOf(root.recommended)) {
            root.pendingTier = choice;
            return;
        }
        root.runCommand(root.tierTool + " set --yes " + choice);
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
        Layout.preferredHeight: Kirigami.Units.gridUnit * 22
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

            // Warning, not a block: the change only happens after "Change anyway".
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.pendingTier !== ""
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "\"" + root.pendingTier.replace("-", " ") + "\" is above what this machine "
                        + "was measured for" + (root.recommended ? " (" + root.recommended + ")" : "")
                        + ". Your PC may slow down or run hotter. Nothing is blocked."
                }
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents3.Button {
                        Layout.fillWidth: true
                        text: "Change anyway"
                        onClicked: {
                            var choice = root.pendingTier;
                            root.pendingTier = "";
                            root.runCommand(root.tierTool + " set --yes " + choice);
                        }
                    }
                    PlasmaComponents3.Button {
                        Layout.fillWidth: true
                        text: "Keep current"
                        onClicked: root.pendingTier = ""
                    }
                }
            }

            Repeater {
                model: root.tiers
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text: modelData.replace("-", " ")
                    checkable: true
                    checked: root.tier === modelData
                    onClicked: root.chooseTier(modelData)
                }
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: "Re-detect hardware"
                onClicked: root.runCommand(root.tierTool + " detect --save")
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: "Scan for missing drivers"
                onClicked: root.runCommand(root.driversTool + " scan --notify")
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: "Local AI"
                font.bold: true
            }

            PlasmaComponents3.Switch {
                id: aiSwitch
                text: root.aiBusy ? "Working…" : "Assistant"
                checked: root.aiEnabled
                enabled: !root.aiBusy
                onClicked: {
                    root.aiBusy = true;
                    root.aiEnableRequested = checked;
                    root.runCommand(root.aiTool + (checked ? " enable" : " disable"));
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.8
                text: {
                    if (root.aiBusy)
                        return "Downloading the runtime, about 1 GB once…";
                    if (!root.aiEnabled)
                        return "Off. Nothing was downloaded; enabling fetches it once.";
                    if (root.aiRuntime === "missing")
                        return "Enabled, runtime not downloaded yet.";
                    return root.aiCaps.length > 0
                        ? "Can: " + root.aiCaps
                        : "Chat only at this tier.";
                }
            }

            // Enabling downloads the runtime once; offer the reboot afterwards.
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.rebootPrompt
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "The local runtime is installed. Reboot now so the assistant "
                        + "starts clean? You can also reboot later."
                }
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents3.Button {
                        Layout.fillWidth: true
                        text: "Reboot now"
                        onClicked: {
                            root.rebootPrompt = false;
                            root.runCommand("/usr/bin/pkexec systemctl reboot");
                        }
                    }
                    PlasmaComponents3.Button {
                        Layout.fillWidth: true
                        text: "Later"
                        onClicked: root.rebootPrompt = false
                    }
                }
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
        id: aiSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            try {
                var state = JSON.parse(data.stdout || "{}");
                root.aiEnabled = state.enabled === true;
                root.aiRuntime = state.runtime || "missing";
                root.aiCaps = (state.capabilities || []).join(", ");
            } catch (error) {
                // The AI tool always exists on Tokoro images; ignore transient errors.
            }
            aiSource.disconnectSource(sourceName);
        }
    }

    PlasmaCore.DataSource {
        id: actionSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            actionSource.disconnectSource(sourceName);
            root.aiBusy = false;
            if (root.aiEnableRequested) {
                root.rebootPrompt = true;
            }
            root.aiEnableRequested = false;
            root.refresh();
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshTier()
    }

    Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshAi()
    }
}
