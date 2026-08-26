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
  property string scriptPath: Qt.resolvedUrl("../scripts/issues.sh").toString().replace(/^file:\/\//, "")

  function refresh() {
    if (proc.running) return
    var cmd = ["bash", scriptPath]
    if (String(cfg.ghOwner || "") !== "") cmd = cmd.concat(["--owner", cfg.ghOwner])
    proc.command = cmd
    proc.running = true
  }

  function open(issue) {
    if (t.bar && issue.url) t.bar.run("xdg-open " + t.bar.shellQuote(issue.url))
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: "github · " + (String(t.cfg.ghOwner || "") !== "" ? t.cfg.ghOwner : "me") + " · open issues+prs"
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: 18
        font.bold: true
      }

      Item { Layout.fillWidth: true }

      Text {
        visible: t.rows.length > 0
        text: t.rows.length + " open"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: 17
      }
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
            title: (modelData.pr ? "[PR] " : "") + "#" + modelData.num + "  " + modelData.title
            sub: modelData.repo + " · updated " + Lib.ago(modelData.updated) + " ago"
            onActivated: t.open(modelData)
          }
        }

        Text {
          visible: t.rows.length === 0 && t.err === ""
          text: proc.running ? "loading…" : "no open issues 🎉"
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
