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
  property var projects: []
  property var series: []
  property int grandTotal: 0
  property string err: ""
  property string hoverInfo: ""
  property string scriptPath: Qt.resolvedUrl("../scripts/posthog.sh").toString().replace(/^file:\/\//, "")
  readonly property var window30: series.slice(-30)
  readonly property real maxCount: {
    var m = 1
    for (var i = 0; i < window30.length; i++) m = Math.max(m, window30[i].count)
    return m
  }

  function refresh() {
    if (proc.running) return
    proc.command = ["bash", scriptPath, "--url", String(cfg.posthogUrl || "https://us.posthog.com")]
    proc.running = true
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: "posthog traffic"
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: 18
        font.bold: true
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

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 12

      ColumnLayout {
        Layout.fillHeight: true
        Layout.preferredWidth: 360
        spacing: 4

        RowLayout {
          Layout.fillWidth: true

          Text {
            text: Lib.fmt(t.grandTotal)
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: 33
            font.bold: true
          }

          Text {
            text: "events all time"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: 15
          }

          Item { Layout.fillWidth: true }

          Text {
            text: t.hoverInfo !== "" ? t.hoverInfo : (t.window30.length > 0 ? "last 30 days" : "")
            color: t.hoverInfo !== "" ? Color.popups.text : Color.muted
            font.family: Style.font.family
            font.pixelSize: 15
          }
        }

        Item {
          id: chart
          Layout.fillWidth: true
          Layout.fillHeight: true

          Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            height: parent.height - 18
            spacing: 2

            Repeater {
              model: t.window30

              delegate: Rectangle {
                id: bar
                required property var modelData
                required property int index

                width: (chart.width - (t.window30.length - 1) * 2) / Math.max(1, t.window30.length)
                height: Math.max(2, (modelData.count / t.maxCount) * chart.height)
                anchors.bottom: parent.bottom
                radius: 1.5
                color: barMouse.containsMouse ? "#b4befe" : "#89b4fa"
                opacity: 0.55 + 0.45 * (index / Math.max(1, t.window30.length - 1))

                MouseArea {
                  id: barMouse
                  anchors.fill: parent
                  anchors.margins: -2
                  hoverEnabled: true
                  acceptedButtons: Qt.NoButton
                  onContainsMouseChanged: t.hoverInfo = containsMouse ? modelData.date + ": " + Lib.fmt(modelData.count) : ""
                }
              }
            }
          }

          Text {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            text: t.window30.length > 0 ? t.window30[0].date : ""
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: 14
          }

          Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            text: t.window30.length > 0 ? t.window30[t.window30.length - 1].date : ""
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: 14
          }
        }
      }

      Rectangle { Layout.fillHeight: true; width: 1; color: "#20ffffff" }

      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentHeight: projCol.height
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: projCol
          width: parent.width
          spacing: 2

          Repeater {
            model: t.projects

            delegate: LineRow {
              required property var modelData

              width: parent.width
              title: modelData.name
              meta: Lib.fmt(modelData.total)
            }
          }
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
          var projErrs = (d.projects || []).filter(function (p) { return !!p.error })
              .map(function (p) { return p.name + ": " + p.error }).join("\n")
          t.err = [d.error || "", projErrs].filter(Boolean).join("\n")
          t.projects = d.projects || []
          t.series = d.series || []
          t.grandTotal = d.total || 0
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
