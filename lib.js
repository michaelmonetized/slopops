.pragma library

function ago(iso) {
  if (!iso) return ""
  var t = Date.parse(iso)
  if (isNaN(t)) return String(iso)
  var s = Math.max(0, (Date.now() - t) / 1000)
  if (s < 60) return Math.floor(s) + "s"
  if (s < 3600) return Math.floor(s / 60) + "m"
  if (s < 86400) return Math.floor(s / 3600) + "h"
  return Math.floor(s / 86400) + "d"
}

function fmt(n) {
  n = Number(n) || 0
  if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
  if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
  if (n >= 1e3) return (n / 1e3).toFixed(1) + "k"
  return String(n)
}

function levelColor(level) {
  var l = String(level || "").toLowerCase()
  if (l === "error" || l === "fatal") return "#f38ba8"
  if (l === "warning") return "#f9e2af"
  return "#89b4fa"
}
