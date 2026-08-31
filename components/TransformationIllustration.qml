import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property string variant: "transform"

  implicitWidth: Style.space(248)
  implicitHeight: Style.space(168)
  Accessible.ignored: true

  Item {
    id: scene
    width: Style.space(248)
    height: Style.space(168)
    anchors.centerIn: parent
    scale: Math.min(1, root.width / width, root.height / height)
    transformOrigin: Item.Center

    Rectangle {
      width: Style.space(132)
      height: width
      radius: width / 2
      x: Style.space(58)
      y: Style.space(18)
      color: Util.alpha(Color.accent, 0.11)
    }

    Item {
      anchors.fill: parent
      visible: root.variant === "transform"

      BorderSurface {
        x: Style.space(20)
        y: Style.space(23)
        width: Style.space(116)
        height: Style.space(122)
        rotation: -6
        radius: Math.max(2, Style.cornerRadius - Style.space(2))
        color: Util.alpha(Color.popups.text, 0.72)
        borderSpec: Border.controlSpec("normal", Color.popups.background, Color.accent)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(14)
          spacing: Style.space(8)

          Text {
            text: "Copiado"
            color: Color.popups.background
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Style.spaceReal(0.8)
          }

          Rectangle { width: parent.width * 0.84; height: Style.space(6); radius: height / 2; color: Color.popups.background }
          Rectangle { width: parent.width * 0.58; height: Style.space(6); radius: height / 2; color: Color.accent }
          Rectangle { width: parent.width * 0.76; height: Style.space(6); radius: height / 2; color: Util.alpha(Color.popups.background, 0.74) }
          Rectangle { width: parent.width * 0.46; height: Style.space(6); radius: height / 2; color: Color.accent }
        }
      }

      BorderSurface {
        x: Style.space(112)
        y: Style.space(20)
        width: Style.space(116)
        height: Style.space(126)
        rotation: 5
        radius: Math.max(2, Style.cornerRadius - Style.space(2))
        color: Color.popups.text
        borderSpec: Border.controlSpec("normal", Color.popups.background, Color.accent)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(14)
          spacing: Style.space(8)

          Text {
            text: "Limpio"
            color: Color.popups.background
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Style.spaceReal(0.8)
          }

          Repeater {
            model: [0.86, 0.72, 0.80, 0.58]
            delegate: Rectangle {
              required property real modelData
              width: parent.width * modelData
              height: Style.space(6)
              radius: height / 2
              color: Color.popups.background
            }
          }
        }

        Rectangle {
          width: Style.space(28)
          height: width
          radius: width / 2
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: Style.space(10)
          color: Color.accent

          Text {
            anchors.centerIn: parent
            text: "✓"
            color: Color.background
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }
        }
      }

      Rectangle {
        width: Style.space(34)
        height: width
        radius: width / 2
        anchors.centerIn: parent
        color: Color.accent

        Text {
          anchors.centerIn: parent
          text: "→"
          color: Color.background
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
        }
      }
    }

    Item {
      anchors.fill: parent
      visible: root.variant === "protect"

      BorderSurface {
        width: Style.space(184)
        height: Style.space(116)
        anchors.centerIn: parent
        radius: Style.cornerRadius
        color: Style.normalFillFor(Color.popups.text, Color.accent)
        borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)

        Column {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(16)
          spacing: Style.space(9)

          Repeater {
            model: ["Imágenes", "Archivos", "Secretos"]
            delegate: Row {
              required property string modelData
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(8)
                height: width
                radius: width / 2
                color: Color.muted
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: modelData
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
          }
        }
      }

      Rectangle {
        width: Style.space(74)
        height: width
        radius: Style.space(18)
        x: Style.space(142)
        y: Style.space(47)
        rotation: 45
        color: Color.accent

        Text {
          anchors.centerIn: parent
          rotation: -45
          text: "✓"
          color: Color.background
          font.family: Style.font.family
          font.pixelSize: Style.font.display
          font.bold: true
        }
      }
    }

    Item {
      anchors.fill: parent
      visible: root.variant === "control"

      BorderSurface {
        width: Style.space(200)
        height: Style.space(126)
        anchors.centerIn: parent
        radius: Style.cornerRadius
        color: Style.normalFillFor(Color.popups.text, Color.accent)
        borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(14)
          spacing: Style.space(9)

          Repeater {
            model: [
              { label: "Automático", active: true },
              { label: "Omitir una copia", active: false },
              { label: "Excluir aplicaciones", active: false }
            ]
            delegate: Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(8)

              Text {
                width: parent.width - Style.space(42)
                text: modelData.label
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                width: Style.space(28)
                height: Style.space(15)
                radius: height / 2
                color: modelData.active ? Color.accent : Util.alpha(Color.popups.text, 0.18)

                Rectangle {
                  width: Style.space(11)
                  height: width
                  radius: width / 2
                  anchors.verticalCenter: parent.verticalCenter
                  x: modelData.active ? parent.width - width - Style.space(2) : Style.space(2)
                  color: modelData.active ? Color.background : Color.popups.text
                }
              }
            }
          }
        }
      }

      Rectangle {
        width: Style.space(34)
        height: width
        radius: width / 2
        x: Style.space(190)
        y: Style.space(16)
        color: Color.accent

        Text {
          anchors.centerIn: parent
          text: "✓"
          color: Color.background
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }
      }
    }
  }
}
