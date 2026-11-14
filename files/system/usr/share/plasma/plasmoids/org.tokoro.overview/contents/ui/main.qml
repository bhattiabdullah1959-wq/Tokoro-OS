import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string monitorTool: "/usr/libexec/tokoro/tokoro-monitor"
    readonly property string appsTool: "/usr/libexec/tokoro/tokoro-apps"

    // monitor --json --no-scan, tokoro-apps --json and the startup list.
    property var monitor: ({})
    property var apps: []
    property var startup: []
    property int tab: 0
    property bool busy: false
    property string notice: ""

    function parse(payload) {
        try {
            return JSON.parse(payload || "{}");
        } catch (error) {
            return {};
        }
    }

    function colourFor(kind) {
        if (kind === "red")
            return Kirigami.Theme.negativeTextColor;
        if (kind === "yellow")
            return Kirigami.Theme.neutralTextColor;
        return Kirigami.Theme.positiveTextColor;
    }

    // The monitor speaks ANSI 256-colour codes for the terminal; the widget needs
    // real colours for the same categories.
    function categoryColour(key) {
        if (key === "photos")
            return "#e56aa8";
        if (key === "videos")
            return "#5aa8e5";
        if (key === "audio")
            return "#e5c85a";
        if (key === "documents")
            return "#6ad07a";
        if (key === "archives")
            return "#a58ae5";
        return "#9a9a9a";
    }

    function run(command) {
        root.busy = true;
        root.notice = "";
        actionSource.connectSource(command);
    }

    function refreshMonitor() {
        monitorSource.connectSource(root.monitorTool + " --json --no-scan");
    }

    function refreshApps() {
        appsSource.connectSource(root.appsTool + " --json");
    }

    function refreshStartup() {
        startupSource.connectSource(root.appsTool + " startup --json");
    }

    function refreshAll() {
        if (root.tab === 0 || root.tab === 1)
            refreshMonitor();
        if (root.tab === 2)
            refreshApps();
        if (root.tab === 3)
            refreshStartup();
    }

    // --- overview + specs ---------------------------------------------------
    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumHeight: Kirigami.Units.gridUnit * 22
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * 30
        collapseMarginsHint: true

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: "System Overview"
                    font.bold: true
                }

                PlasmaComponents3.Label {
                    text: root.busy ? "working…" : ""
                    opacity: 0.6
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: root.refreshAll()
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: root.notice !== ""
                text: root.notice
                color: Kirigami.Theme.negativeTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                wrapMode: Text.Wrap
            }

            PlasmaComponents3.TabBar {
                id: tabs
                Layout.fillWidth: true
                onCurrentIndexChanged: {
                    root.tab = currentIndex;
                    root.refreshAll();
                }

                PlasmaComponents3.TabButton { text: "Overview" }
                PlasmaComponents3.TabButton { text: "Specs" }
                PlasmaComponents3.TabButton { text: "Apps" }
                PlasmaComponents3.TabButton { text: "Startup" }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.tab

                // ------------------------------------------------------ Overview
                Flickable {
                    contentWidth: width
                    contentHeight: overview.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: overview
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        UsageBar {
                            Layout.fillWidth: true
                            label: "CPU"
                            value: root.monitor.cpu ? root.monitor.cpu.usage : 0
                            detail: root.monitor.cpu
                                ? (root.monitor.cpu.cores + " cores / "
                                   + root.monitor.cpu.threads + " threads · load "
                                   + ((root.monitor.cpu.load || []).join(" ")))
                                : ""
                        }

                        UsageBar {
                            Layout.fillWidth: true
                            label: "RAM"
                            value: root.monitor.memory ? root.monitor.memory.percent : 0
                            detail: root.monitor.memory
                                ? (root.monitor.memory.used_gb.toFixed(1) + " / "
                                   + root.monitor.memory.total_gb.toFixed(1) + " GB used")
                                : ""
                        }

                        UsageBar {
                            Layout.fillWidth: true
                            visible: root.monitor.storage !== undefined
                            label: "Disk"
                            value: root.monitor.storage ? root.monitor.storage.percent : 0
                            detail: root.monitor.storage
                                ? (root.monitor.storage.used_gb.toFixed(1) + " / "
                                   + root.monitor.storage.total_gb.toFixed(1) + " GB used · "
                                   + root.monitor.storage.free_gb.toFixed(1) + " GB free")
                                : ""
                        }

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            visible: root.monitor.gpus !== undefined
                                     && (root.monitor.gpus || []).length > 0
                            text: {
                                var list = root.monitor.gpus || [];
                                if (list.length === 0)
                                    return "";
                                var gpu = list[0];
                                if (gpu.vram_total_mb > 0)
                                    return gpu.name + " · VRAM "
                                        + (gpu.vram_used_mb / 1024).toFixed(1) + " / "
                                        + (gpu.vram_total_mb / 1024).toFixed(1) + " GB";
                                return gpu.name;
                            }
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.8
                        }

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: "What is using the disk"
                            font.bold: true
                            topPadding: Kirigami.Units.smallSpacing
                        }

                        Repeater {
                            model: root.monitor.storage ? (root.monitor.storage.breakdown || []) : []

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Kirigami.Units.smallSpacing

                                    PlasmaComponents3.Label {
                                        Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                                        text: modelData.label
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: Kirigami.Units.gridUnit * 0.5
                                        radius: 2
                                        color: Qt.rgba(Kirigami.Theme.textColor.r,
                                                       Kirigami.Theme.textColor.g,
                                                       Kirigami.Theme.textColor.b, 0.15)

                                        Rectangle {
                                            width: parent.width * Math.min(1, modelData.share / 100)
                                            height: parent.height
                                            radius: 2
                                            color: root.categoryColour(modelData.key)
                                        }
                                    }

                                    PlasmaComponents3.Label {
                                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                        horizontalAlignment: Text.AlignRight
                                        text: modelData.share.toFixed(0) + "%"
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    }
                                }
                            }
                        }

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            visible: root.monitor.storage === undefined
                            text: "Collecting numbers…"
                            opacity: 0.6
                        }
                    }
                }

                // --------------------------------------------------------- Specs
                Flickable {
                    contentWidth: width
                    contentHeight: specs.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: specs
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        SpecRow {
                            Layout.fillWidth: true
                            term: "System"
                            value: root.monitor.system ? root.monitor.system.os : ""
                        }
                        SpecRow {
                            Layout.fillWidth: true
                            term: "Kernel"
                            value: root.monitor.system ? root.monitor.system.kernel : ""
                        }
                        SpecRow {
                            Layout.fillWidth: true
                            term: "Host"
                            value: root.monitor.system ? root.monitor.system.hostname : ""
                        }
                        SpecRow {
                            Layout.fillWidth: true
                            term: "CPU"
                            value: root.monitor.cpu ? root.monitor.cpu.model : ""
                        }
                        SpecRow {
                            Layout.fillWidth: true
                            term: "Cores"
                            value: root.monitor.cpu
                                ? (root.monitor.cpu.cores + " cores · "
                                   + root.monitor.cpu.threads + " threads")
                                : ""
                        }
                        SpecRow {
                            Layout.fillWidth: true
                            term: "Memory"
                            value: root.monitor.memory
                                ? (root.monitor.memory.total_gb.toFixed(1) + " GB · "
                                   + root.monitor.memory.available_gb.toFixed(1) + " GB free")
                                : ""
                        }
                        SpecRow {
                            Layout.fillWidth: true
                            term: "Swap"
                            value: root.monitor.memory
                                ? (root.monitor.memory.swap_total_gb.toFixed(1) + " GB")
                                : ""
                        }
                        Repeater {
                            model: root.monitor.gpus || []
                            SpecRow {
                                Layout.fillWidth: true
                                term: "GPU"
                                value: modelData.vram_total_mb > 0
                                    ? (modelData.name + " · "
                                       + (modelData.vram_total_mb / 1024).toFixed(1) + " GB VRAM")
                                    : modelData.name
                            }
                        }
                        SpecRow {
                            Layout.fillWidth: true
                            term: "Storage"
                            value: root.monitor.storage
                                ? (root.monitor.storage.total_gb.toFixed(1) + " GB · "
                                   + root.monitor.storage.free_gb.toFixed(1) + " GB free at "
                                   + root.monitor.storage.path)
                                : ""
                        }
                        SpecRow {
                            Layout.fillWidth: true
                            term: "Files"
                            value: root.monitor.storage
                                ? (root.monitor.storage.files_scanned + " scanned")
                                : ""
                        }

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            visible: root.monitor.cpu === undefined
                            text: "Collecting numbers…"
                            opacity: 0.6
                        }
                    }
                }

                // ---------------------------------------------------------- Apps
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            opacity: 0.7
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            text: "Right-click an app to close it or keep it in the background"
                        }

                        PlasmaComponents3.ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                id: appList
                                model: root.apps
                                spacing: Kirigami.Units.smallSpacing

                                delegate: Item {
                                    width: appList.width
                                    height: Kirigami.Units.gridUnit * 2.4

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 3
                                        color: Qt.rgba(Kirigami.Theme.textColor.r,
                                                       Kirigami.Theme.textColor.g,
                                                       Kirigami.Theme.textColor.b, 0.06)
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 3
                                        radius: 1.5
                                        color: root.colourFor(modelData.class)
                                    }

                                    ColumnLayout {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Kirigami.Units.smallSpacing + 3
                                        anchors.right: parent.right
                                        anchors.rightMargin: Kirigami.Units.smallSpacing
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 0

                                        PlasmaComponents3.Label {
                                            Layout.fillWidth: true
                                            text: modelData.name + (modelData.state === "suspended"
                                                                    ? "  (in background)" : "")
                                            elide: Text.ElideRight
                                            font.bold: true
                                        }

                                        PlasmaComponents3.Label {
                                            Layout.fillWidth: true
                                            opacity: 0.7
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            text: modelData.rss_mb.toFixed(0) + " MB · "
                                                  + modelData.cpu_percent.toFixed(1) + "% CPU · pid "
                                                  + modelData.pid
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: (mouse) => {
                                            if (mouse.button !== Qt.RightButton)
                                                return;
                                            appMenu.pid = modelData.pid;
                                            appMenu.appName = modelData.name;
                                            appMenu.suspended = modelData.state === "suspended";
                                            appMenu.popup();
                                        }
                                    }
                                }
                            }
                        }

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            visible: root.apps.length === 0
                            text: "No running apps found"
                            opacity: 0.6
                        }
                    }
                }

                // ------------------------------------------------------- Startup
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            opacity: 0.7
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            text: "Apps that start when you sign in"
                        }

                        PlasmaComponents3.ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                id: startupList
                                model: root.startup
                                spacing: Kirigami.Units.smallSpacing

                                delegate: Item {
                                    width: startupList.width
                                    height: Kirigami.Units.gridUnit * 2.2

                                    PlasmaComponents3.Label {
                                        anchors.left: parent.left
                                        anchors.right: startupSwitch.left
                                        anchors.rightMargin: Kirigami.Units.smallSpacing
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name
                                        elide: Text.ElideRight
                                    }

                                    PlasmaComponents3.Switch {
                                        id: startupSwitch
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: modelData.enabled
                                        // The model is reloaded after every change; ignore the
                                        // binding churn so a refresh cannot toggle anything.
                                        onCheckedChanged: {
                                            if (checked === modelData.enabled)
                                                return;
                                            root.run(root.appsTool + " startup "
                                                     + (checked ? "enable " : "disable ")
                                                     + modelData.id);
                                        }
                                    }
                                }
                            }
                        }

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            visible: root.startup.length === 0
                            text: "No startup apps found"
                            opacity: 0.6
                        }
                    }
                }
            }
        }
    }

    compactRepresentation: Item {
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: Kirigami.Units.iconSizes.smallMedium

        Kirigami.Icon {
            anchors.fill: parent
            source: "utilities-system-monitor"
            active: compactMouse.containsMouse
        }

        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    // Right-click menu for a running app.
    PlasmaComponents3.Menu {
        id: appMenu

        property int pid: -1
        property string appName: ""
        property bool suspended: false

        PlasmaComponents3.MenuItem {
            text: "Close " + appMenu.appName
            icon.name: "window-close"
            onClicked: root.run(root.appsTool + " close " + appMenu.pid)
        }

        PlasmaComponents3.MenuItem {
            text: appMenu.suspended ? "Bring back" : "Keep in background"
            icon.name: appMenu.suspended ? "media-playback-start" : "media-playback-pause"
            onClicked: root.run(root.appsTool + (appMenu.suspended ? " resume " : " background ")
                                + appMenu.pid)
        }
    }

    Plasmoid.toolTipMainText: "System Overview"
    Plasmoid.toolTipSubText: root.monitor.memory
        ? ("RAM " + root.monitor.memory.percent.toFixed(0) + "% · CPU "
           + (root.monitor.cpu ? root.monitor.cpu.usage.toFixed(0) : "0") + "%")
        : "Click to open"

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // --- data ---------------------------------------------------------------
    Plasma5Support.DataSource {
        id: monitorSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            var payload = root.parse(data.stdout);
            if (payload.cpu !== undefined)
                root.monitor = payload;
            monitorSource.disconnectSource(sourceName);
        }
    }

    Plasma5Support.DataSource {
        id: appsSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            var payload = root.parse(data.stdout);
            root.apps = payload.apps || [];
            appsSource.disconnectSource(sourceName);
        }
    }

    Plasma5Support.DataSource {
        id: startupSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            var payload = root.parse(data.stdout);
            root.startup = payload.startup || [];
            startupSource.disconnectSource(sourceName);
        }
    }

    Plasma5Support.DataSource {
        id: actionSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            root.busy = false;
            root.notice = (data.stderr || "").trim();
            actionSource.disconnectSource(sourceName);
            root.refreshAll();
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.expanded && (root.tab === 0 || root.tab === 1)
        onTriggered: root.refreshMonitor()
    }

    Timer {
        interval: 2500
        repeat: true
        running: root.expanded && root.tab === 2
        onTriggered: root.refreshApps()
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.expanded && root.tab === 3
        onTriggered: root.refreshStartup()
    }

    Component.onCompleted: refreshAll()
}

// A labelled percentage bar used by the Overview tab.
component UsageBar: ColumnLayout {
    property string label: ""
    property real value: 0
    property string detail: ""

    spacing: 1

    RowLayout {
        Layout.fillWidth: true

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: label
            font.bold: true
        }

        PlasmaComponents3.Label {
            text: Math.round(value) + "%"
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: Kirigami.Units.gridUnit * 0.6
        radius: 3
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b, 0.15)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, value / 100))
            height: parent.height
            radius: 3
            color: value >= 85 ? Kirigami.Theme.negativeTextColor
                 : value >= 60 ? Kirigami.Theme.neutralTextColor
                 : Kirigami.Theme.highlightColor
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        text: detail
        visible: detail !== ""
        opacity: 0.65
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        elide: Text.ElideRight
    }
}

// One label/value row on the Specs tab.
component SpecRow: RowLayout {
    property string term: ""
    property string value: ""

    PlasmaComponents3.Label {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 4
        text: term
        opacity: 0.7
        font.pointSize: Kirigami.Theme.smallFont.pointSize
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        text: value !== "" ? value : "—"
        wrapMode: Text.WrapAnywhere
    }
}
