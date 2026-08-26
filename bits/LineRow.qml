import QtQuick
import qs.Commons

// One row in a tab list: main line with optional right-aligned extras.
Rectangle {
  id: row

  property string title: ""
  property string sub: ""
  property string meta: ""
  property bool pinnedRow: false
  signal activated
  default property alias content: extra.children

  height: Math.max(30, mainCol.implicitHeight + 10)
  radius: 6
  color: pinnedRow ? "#28f38ba8" : mouse.containsMouse ? "#14ffffff" : "transparent"

  Column {
    id: mainCol
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.rightMargin: extra.width > 0 ? extra.width + 12 : 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Text {
      width: parent.width
      elide: Text.ElideRight
      text: row.title
      color: Color.popups.text
      font.pixelSize: 18
      font.family: Style.font.family
    }

    Text {
      visible: row.sub !== ""
      width: parent.width
      elide: Text.ElideRight
      text: row.sub
      color: Color.muted
      font.pixelSize: 15
      font.family: Style.font.family
    }
  }

  Item {
    id: extra
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    width: childrenRect.width
    height: childrenRect.height
  }

  Text {
    visible: row.meta !== "" && extra.width === 0
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    text: row.meta
    color: Color.muted
    font.pixelSize: 15
    font.family: Style.font.family
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: row.activated()
  }
}
