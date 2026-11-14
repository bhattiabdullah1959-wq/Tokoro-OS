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

    readonly property string nowTool: "/usr/libexec/tokoro/tokoro-nowplaying"
    readonly property string libraryTool: "/usr/libexec/tokoro/tokoro-library"
    readonly property string levelsTool: "/usr/libexec/tokoro/tokoro-levels"
    readonly property string musicTool: "/usr/libexec/tokoro/tokoro-music"

    property bool playing: false
    property string status: "Stopped"
    property string title: ""
    property string artist: ""
    property string album: ""
    property string art: ""
    property string playerName: ""
    property var tracks: []
    property var levels: []
    property bool realLevels: false
    // Only the two best tiers animate; below that the bars stay flat and cava is
    // never started, which keeps the widget free on battery/frame-focused tiers.
    property bool levelsAnimated: false
    property string busyAction: ""

    // Popup geometry: tall enough that the list scrolls instead of the panel.
    fullRepresentation: PlasmaExtras.Representation {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 19
        Layout.preferredHeight: Kirigami.Units.gridUnit * 24
        collapseMarginsHint: true

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                    source: root.art !== "" ? root.art : "media-playback-start"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: root.title !== "" ? root.title : "Nothing playing"
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        opacity: 0.8
                        elide: Text.ElideRight
                        text: {
                            if (root.artist !== "" && root.album !== "")
                                return root.artist + " — " + root.album;
                            if (root.artist !== "")
                                return root.artist;
                            if (root.playerName !== "")
                                return root.playerName.replace("org.mpris.MediaPlayer2.", "");
                            return "Start a player (Spotify, Elisa, …)";
                        }
                    }
                }

                PlasmaComponents3.Label {
                    opacity: 0.6
                    text: root.realLevels ? "live" : ""
                }
            }

            // Level bars: real spectrum from cava when installed, otherwise a
            // pulse that follows playback (the label above says which).
            RowLayout {
                id: bars
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.2
                spacing: 2

                Repeater {
                    model: root.levels

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            radius: 1
                            color: Kirigami.Theme.highlightColor
                            opacity: 0.35 + 0.65 * (modelData / 100)
                            height: parent.height * (0.12 + 0.88 * modelData / 100)
                        }
                    }
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: !root.levelsAnimated
                opacity: 0.55
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                text: "Bars animate on the Quality and Ultra Quality tiers"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text: "Previous"
                    icon.name: "media-skip-backward"
                    enabled: root.playerName !== ""
                    onClicked: {
                        root.busyAction = "previous";
                        actionSource.connectSource(root.nowTool + " previous");
                    }
                }
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text: root.playing ? "Pause" : "Play"
                    icon.name: root.playing ? "media-playback-pause" : "media-playback-start"
                    enabled: root.playerName !== ""
                    onClicked: {
                        root.busyAction = "play-pause";
                        actionSource.connectSource(root.nowTool + " play-pause");
                    }
                }
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text: "Next"
                    icon.name: "media-skip-forward"
                    enabled: root.playerName !== ""
                    onClicked: {
                        root.busyAction = "next";
                        actionSource.connectSource(root.nowTool + " next");
                    }
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: "Your music"
                font.bold: true
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                opacity: 0.7
                wrapMode: Text.WordWrap
                visible: root.tracks.length === 0
                text: "No local music indexed yet. Add files to ~/Music, then: "
                    + "tokoro library --refresh"
            }

            ListView {
                id: trackList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.tracks
                spacing: 1
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    required property var modelData
                    width: trackList.width
                    height: Kirigami.Units.gridUnit * 1.9

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: trackMouse.containsMouse
                            ? Kirigami.Theme.highlightColor : "transparent"
                        opacity: trackMouse.containsMouse ? 0.25 : 1
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: 0

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: modelData.title
                            elide: Text.ElideRight
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            opacity: 0.65
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            elide: Text.ElideRight
                            text: modelData.artist !== "" ? modelData.artist : modelData.album
                        }
                    }

                    MouseArea {
                        id: trackMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.busyAction = "play-file";
                            actionSource.connectSource(
                                root.musicTool + " --play " + "\"" + modelData.path + "\"");
                        }
                    }
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                text: "Scroll to browse · click to play in your local player"
            }
        }
    }

    compactRepresentation: Item {
        // The panel reserves space from the implicit size; without it the icon
        // is invisible.
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: Kirigami.Units.iconSizes.smallMedium

        Kirigami.Icon {
            anchors.fill: parent
            source: root.playing ? "media-playback-pause" : "media-playback-start"
            active: compactMouse.containsMouse
        }

        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    Plasmoid.toolTipMainText: root.title !== "" ? root.title : "No music playing"
    Plasmoid.toolTipSubText: root.artist !== ""
        ? root.artist + (root.playing ? " · playing" : " · paused")
        : "Click to open the player"

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    function refreshNow() {
        nowSource.connectSource(root.nowTool + " --json");
    }

    function refreshLibrary() {
        librarySource.connectSource(root.libraryTool + " --json");
    }

    function refreshLevels() {
        levelsSource.connectSource(root.levelsTool + " --json --count 24");
    }

    function applyLevels(data) {
        try {
            var payload = JSON.parse(data.stdout || "{}");
            root.levels = payload.bars || [];
            root.realLevels = payload.source === "cava";
            root.levelsAnimated = payload.animated === true;
        } catch (error) {
            root.levels = [];
        }
    }

    Plasma5Support.DataSource {
        id: nowSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            try {
                var state = JSON.parse(data.stdout || "{}");
                root.status = state.status || "Stopped";
                root.playing = root.status === "Playing";
                root.title = state.title || "";
                root.artist = state.artist || "";
                root.album = state.album || "";
                root.art = state.art || "";
                root.playerName = state.player || "";
            } catch (error) {
                root.playing = false;
            }
            nowSource.disconnectSource(sourceName);
        }
    }

    Plasma5Support.DataSource {
        id: librarySource
        engine: "executable"
        onNewData: (sourceName, data) => {
            try {
                var payload = JSON.parse(data.stdout || "{}");
                root.tracks = payload.tracks || [];
            } catch (error) {
                root.tracks = [];
            }
            librarySource.disconnectSource(sourceName);
        }
    }

    Plasma5Support.DataSource {
        id: levelsSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            root.applyLevels(data);
            levelsSource.disconnectSource(sourceName);
        }
    }

    Plasma5Support.DataSource {
        id: actionSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            actionSource.disconnectSource(sourceName);
            root.busyAction = "";
            root.refreshNow();
        }
    }

    // Now-playing metadata: cheap (one busctl call).
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshNow()
    }

    // Library index: only when it has never been read.
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.tracks.length === 0) {
                root.refreshLibrary();
            }
        }
    }

    // Levels: animating costs CPU, so only Quality and Ultra Quality animate.
    // On lower tiers a slow poll is enough to notice a tier change.
    Timer {
        interval: 120
        running: root.levelsAnimated && root.realLevels
        repeat: true
        onTriggered: root.refreshLevels()
    }

    Timer {
        interval: 700
        running: root.levelsAnimated && !root.realLevels
        repeat: true
        onTriggered: root.refreshLevels()
    }

    Timer {
        interval: 20000
        running: !root.levelsAnimated
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshLevels()
    }
}
