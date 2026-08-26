import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import "../lib.js" as Lib
import "../bits"

Item {
  id: t

  property var cfg: ({})
  property var bar: null
  property var rows: []
  property string err: ""
  property string scriptPath: Qt.resolvedUrl("../scripts/vercel.sh").toString().replace(/^file:\/\//, "")
  readonly property int pinnedCount: rows.filter(function (r) { return r.pinned }).length

  function stateColor(state) {
    var s = String(state || "").toUpperCase()
    if (s === "READY") return "#a6e3a1"
    if (s === "ERROR") return "#f38ba8"
    if (s === "CANCELED" || s === "DELETED") return "#585b70"
    return "#f9e2af"
  }

  function refresh() {
    if (proc.running) return
    var cmd = ["bash", scriptPath]
    if (String(cfg.vercelTeamId || "") !== "") cmd = cmd.concat(["--team-id", cfg.vercelTeamId])
    proc.command = cmd
    proc.running = true
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: "vercel deployments"
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: 18
        font.bold: true
      }

      Text {
        visible: t.pinnedCount > 0
        text: t.pinnedCount + " failing since last good deploy"
        color: "#f38ba8"
        font.family: Style.font.family
        font.pixelSize: 17
      }

      Item { Layout.fillWidth: true }
    }

    Text {
      Layout.fillWidth: true
      visible: t.err !== ""
      text: t.err
      color: "#f9e2af"
      font.family: Style.font.family
      font.pixelSize: 17
      wrapMode: Text.Wrap
    }

    Flickable {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      contentHeight: listCol.height
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: listCol
        width: t.width
        spacing: 2

        Repeater {
          model: t.rows

          delegate: LineRow {
            required property var modelData

            width: parent.width
            pinnedRow: modelData.pinned
            title: (modelData.pinned ? "!  " : "") + modelData.name
            sub: modelData.url
            onActivated: if (!!modelData.url && t.bar) t.bar.run("xdg-open " + t.bar.shellQuote(modelData.url))

            Row {
              spacing: 8

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: stateText.implicitWidth + 10
                height: 18
                radius: 9
                color: Qt.rgba(0, 0, 0, 0.001)
                border.color: t.stateColor(modelData.state)

                Text {
                  id: stateText
                  anchors.centerIn: parent
                  text: modelData.state
                  color: t.stateColor(modelData.state)
                  font.family: Style.font.family
                  font.pixelSize: 14
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: modelData.errs > 0
                text: modelData.errs + " err"
                color: "#f38ba8"
                font.family: Style.font.family
                font.pixelSize: 15
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.when
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: 15
              }
            }
          }
        }

        Text {
          visible: t.rows.length === 0 && t.err === ""
          text: proc.running ? "loading…" : "no data yet"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: 17
        }
      }
    }
  }

  Process {
    id: proc

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          t.err = d.error || ""
          t.rows = d.rows || []
        } catch (e) {
          t.err = "bad output: " + e
        }
      }
    }
  }

  Timer {
    interval: Math.max(30, Number(t.cfg.refreshSeconds) || 90) * 1000
    running: t.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: t.refresh()
  }
}
