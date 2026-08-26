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
  property var groups: []
  property int totalEvents: 0
  property string err: ""
  property string scriptPath: Qt.resolvedUrl("../scripts/sentry.sh").toString().replace(/^file:\/\//, "")

  function refresh() {
    if (proc.running) return
    var cmd = ["bash", scriptPath]
    if (String(cfg.sentryOrg || "") !== "") cmd = cmd.concat(["--org", cfg.sentryOrg])
    if (String(cfg.sentryUrl || "") !== "") cmd = cmd.concat(["--url", cfg.sentryUrl])
    proc.command = cmd
    proc.running = true
  }

  function promote(issue) {
    var repo = String(cfg.issueRepo || "")
    if (!t.bar) return
    if (repo === "") {
      t.bar.run("notify-send -a 'Ops' 'Promote' 'Set issueRepo (owner/repo) in widget settings first'")
      return
    }
    var args = ["bash", scriptDirPath(), repo,
                "[sentry] " + issue.title,
                issue.url || "", issue.culprit || "",
                issue.level || "", String(issue.count || 0)]
    var quoted = args.map(function (a) { return t.bar.shellQuote(a) }).join(" ")
    t.bar.run(quoted)
  }

  function scriptDirPath() {
    return Qt.resolvedUrl("../scripts/promote.sh").toString().replace(/^file:\/\//, "")
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: "sentry · unresolved 24h"
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: 18
        font.bold: true
      }

      Text {
        visible: t.totalEvents > 0
        text: Lib.fmt(t.totalEvents) + " events"
        color: "#f38ba8"
        font.family: Style.font.family
        font.pixelSize: 17
      }

      Item { Layout.fillWidth: true }

      Text {
        text: "promotes to an issue in " + (String(t.cfg.issueRepo || "") !== "" ? t.cfg.issueRepo : "(set issueRepo)")
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: 15
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
        spacing: 3

        Repeater {
          model: t.groups

          delegate: Column {
            id: groupCol
            required property var modelData

            width: parent.width
            spacing: 2

            Text {
              text: groupCol.modelData.project
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: 17
              font.bold: true
              leftPadding: 4
            }

            Repeater {
              model: groupCol.modelData.issues

              delegate: LineRow {
                id: issueRow
                required property var modelData

                width: parent.width
                title: modelData.title
                sub: (modelData.culprit || "") + " · last seen " + Lib.ago(modelData.lastSeen) + " ago"
                onActivated: if (!!modelData.url && t.bar) t.bar.run("xdg-open " + t.bar.shellQuote(modelData.url))

                Row {
                  spacing: 8

                  Rectangle {
                    width: promoteLabel.implicitWidth + 14
                    height: 20
                    radius: 10
                    border.color: "#40ffffff"
                    color: promoteMouse.containsMouse ? "#20ffffff" : "transparent"

                    Text {
                      id: promoteLabel
                      anchors.centerIn: parent
                      text: "+ issue"
                      color: Color.popups.text
                      font.family: Style.font.family
                      font.pixelSize: 14
                    }

                    MouseArea {
                      id: promoteMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: t.promote(issueRow.modelData)
                    }
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "x" + Lib.fmt(modelData.count)
                    color: Lib.levelColor(modelData.level)
                    font.family: Style.font.family
                    font.pixelSize: 15
                    font.bold: true
                  }
                }
              }
            }
          }
        }

        Text {
          visible: t.groups.length === 0 && t.err === ""
          text: proc.running ? "loading…" : "nothing unresolved 🎉 or tokens missing"
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
          t.groups = d.groups || []
          t.totalEvents = d.total || 0
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
