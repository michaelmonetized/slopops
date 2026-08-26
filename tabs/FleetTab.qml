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
  property var peers: []
  property string err: ""
  property string scriptPath: Qt.resolvedUrl("../scripts/fleet.sh").toString().replace(/^file:\/\//, "")
  readonly property var cols: {
    var c = ["ts"]
    var ports = String(cfg.fleetPorts || "").split(",")
    for (var i = 0; i < ports.length; i++) {
      var p = ports[i].trim()
      if (p !== "") c.push(p)
    }
    if ((cfg.t3Port || 0) > 0) c.push("t3")
    return c
  }

  function lightState(peer, col) {
    if (!peer.online) return "na"
    if (col === "ts") return "ok"
    if (col === "t3") return peer.t3 === true ? "ok" : "down"
    var v = (peer.services || {})[col]
    return v === true ? "ok" : v === false ? "down" : "na"
  }

  function refresh() {
    if (proc.running) return
    proc.command = ["bash", scriptPath, "--ports", String(cfg.fleetPorts || ""),
                    "--t3-port", String(cfg.t3Port || 0)]
    proc.running = true
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: "fleet"
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: 18
        font.bold: true
      }

      Text {
        property int onlineCount: t.peers.filter(function (p) { return p.online }).length
        text: t.peers.length > 0 ? onlineCount + "/" + t.peers.length + " online" : ""
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: 17
      }

      Item { Layout.fillWidth: true }

      Repeater {
        model: t.cols

        Row {
            required property string modelData
          spacing: 4

          StatusLight { state: "ok" }
          Text {
            text: parent.modelData
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: 15
            anchors.verticalCenter: parent.verticalCenter
          }
        }
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
          model: t.peers

          delegate: Rectangle {
            id: peerRow
            required property var modelData

            width: parent.width
            height: 30
            radius: 6
            color: "#08ffffff"

            Rectangle {
              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              width: 8
              height: 8
              radius: 4
              color: peerRow.modelData.online ? "#a6e3a1" : "#585b70"
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 24
              anchors.verticalCenter: parent.verticalCenter
              text: peerRow.modelData.name + (peerRow.modelData.self ? "  (this machine)" : "")
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: 18
              elide: Text.ElideRight
              width: parent.width - 160
            }

            Text {
              anchors.right: lightsRow.left
              anchors.rightMargin: 14
              anchors.verticalCenter: parent.verticalCenter
              text: peerRow.modelData.ip
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: 15
            }

            Row {
              id: lightsRow
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              spacing: 10

              Repeater {
                model: t.cols

                StatusLight {
                  required property string modelData
                  state: t.lightState(peerRow.modelData, modelData)
                }
              }
            }
          }
        }

        Text {
          visible: t.peers.length === 0 && t.err === "" && !fetching.visible
          text: "no devices yet — waiting for first scan"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: 17
        }
      }
    }
  }

  Text {
    id: fetching
    visible: proc.running
    anchors.centerIn: parent
    text: "probing…"
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: 17
  }

  Process {
    id: proc

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          t.err = d.error || ""
          t.peers = d.peers || []
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
