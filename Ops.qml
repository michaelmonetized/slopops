import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "slopops"
  ipcTarget: "slopops"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property var cfg: ({
    refreshSeconds: Math.max(30, Number(setting("refreshSeconds", 90)) || 90),
    fleetPorts: String(setting("fleetPorts", "22,5900")),
    t3Port: Number(setting("t3Port", 3773)) || 0,
    vercelTeamId: String(setting("vercelTeamId", "")),
    sentryOrg: String(setting("sentryOrg", "")),
    sentryUrl: String(setting("sentryUrl", "https://sentry.io")),
    posthogUrl: String(setting("posthogUrl", "https://us.posthog.com")),
    issueRepo: String(setting("issueRepo", "")),
    ghOwner: String(setting("ghOwner", ""))
  })
  readonly property string scriptDir: Qt.resolvedUrl("scripts/").toString().replace(/^file:\/\//, "")

  property var badge: ({})
  property int tabIndex: 0
  readonly property var tabs: ["Fleet", "Deploys", "Sentry", "Traffic", "Issues"]

  readonly property string badgeColor: {
    var c = badge.creds || {}
    if ((badge.deployErrors || 0) > 0 || (badge.sentryErrors || 0) > 0) return "#f38ba8"
    if (!c.vercel || !c.sentry || !c.posthog) return "#f9e2af"
    if ((badge.offlinePeers || 0) > 0) return "#f9e2af"
    return "#a6e3a1"
  }
  readonly property string badgeTip: {
    var d = badge.deployErrors || 0, s = badge.sentryErrors || 0
    if (d || s) return "ops: " + d + " deploy project(s) failing · " + s + " sentry events"
    return "ops: nominal"
  }

  function refreshAll() {
    if (fleetTab.item) fleetTab.item.refresh()
    if (deployTab.item) deployTab.item.refresh()
    if (sentryTab.item) sentryTab.item.refresh()
    if (trafficTab.item) trafficTab.item.refresh()
    if (issueTab.item) issueTab.item.refresh()
    poll()
  }

  function poll() {
    if (!badgeProc.running)
      badgeProc.command = ["bash", scriptDir + "status.sh",
                           "--org", cfg.sentryOrg, "--url", cfg.sentryUrl]
    if (badgeProc.command.length > 1) badgeProc.running = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf233"
    tooltipText: root.badgeTip
    onPressed: function(b) {
      if (b === Qt.RightButton) root.refreshAll()
      else root.toggle()
    }
  }

  Rectangle {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 3
    width: 7
    height: 7
    radius: 3.5
    color: root.badgeColor
    border.color: "#11111b"
    border.width: 1
  }

  PopupCard {
    id: card
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: Style.space(620)
    contentHeight: Style.space(450)

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.space(3)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(3)

        Text {
          text: "ops"
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: 23
          font.bold: true
        }

        Item { Layout.fillWidth: true }

        Repeater {
          model: root.tabs

          Rectangle {
            id: tabChip
            required property int index
            required property string modelData

            Layout.preferredWidth: chipText.implicitWidth + 18
            Layout.preferredHeight: 24
            radius: 12
            color: root.tabIndex === tabChip.index ? Color.accent : mouse.containsMouse ? "#14ffffff" : "transparent"

            Text {
              id: chipText
              anchors.centerIn: parent
              text: parent.modelData
              color: root.tabIndex === parent.index ? "#11111b" : Color.muted
              font.family: Style.font.family
              font.pixelSize: 17
            }

            MouseArea {
              id: mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.tabIndex = parent.index
            }
          }
        }

        Text {
          text: "\u27f3"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: 20

          MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.refreshAll()
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: "#20ffffff" }

      StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: root.tabIndex

        Loader { id: fleetTab; source: "tabs/FleetTab.qml"; onLoaded: { item.cfg = root.cfg; item.bar = root.bar } }
        Loader { id: deployTab; source: "tabs/DeploymentsTab.qml"; onLoaded: { item.cfg = root.cfg; item.bar = root.bar } }
        Loader { id: sentryTab; source: "tabs/SentryTab.qml"; onLoaded: { item.cfg = root.cfg; item.bar = root.bar } }
        Loader { id: trafficTab; source: "tabs/TrafficTab.qml"; onLoaded: { item.cfg = root.cfg; item.bar = root.bar } }
        Loader { id: issueTab; source: "tabs/IssuesTab.qml"; onLoaded: { item.cfg = root.cfg; item.bar = root.bar } }
      }
    }
  }

  Timer {
    interval: root.cfg.refreshSeconds * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.poll()
  }

  onOpenedChanged: if (opened) refreshAll()

  Process {
    id: badgeProc
    stdout: SplitParser {
      onRead: function(line) {
        try { root.badge = JSON.parse(line) } catch (e) {}
      }
    }
  }
}
