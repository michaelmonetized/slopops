import QtQuick

// Small round status light. state: "ok" | "warn" | "down" | "na"
Rectangle {
  property string state: "na"

  width: 9
  height: 9
  radius: 5
  anchors.verticalCenter: parent ? parent.verticalCenter : undefined
  color: state === "ok" ? "#a6e3a1" : state === "warn" ? "#f9e2af" : state === "down" ? "#f38ba8" : "#585b70"
  opacity: state === "na" ? 0.45 : 1.0
}
