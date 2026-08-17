import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Dialog {
    id: root
    objectName: "middlePanelColorDialog"

    readonly property string selectedColor: colorInput.acceptableInput
                                            ? colorInput.text.toUpperCase() : "#000000"
    property real selectedHue: 0
    property real selectedSaturation: 0
    property real selectedValue: 1
    property int selectedAlpha: 255
    property bool syncingColor: false

    width: Math.min(560, parent ? parent.width - 24 : 560)
    height: Math.min(570, parent ? parent.height - 24 : 570)
    anchors.centerIn: Overlay.overlay
    modal: true
    padding: 24
    closePolicy: Popup.CloseOnEscape

    function hexByte(value) {
        const hex = Math.round(Math.max(0, Math.min(255, value))).toString(16)
        return (hex.length === 1 ? "0" + hex : hex).toUpperCase()
    }

    function hueColor() {
        return Qt.hsva(selectedHue, 1, 1, 1)
    }

    function opaqueColor() {
        return Qt.hsva(selectedHue, selectedSaturation, selectedValue, 1)
    }

    function updateColorText() {
        const picked = opaqueColor()
        const rgb = hexByte(picked.r * 255) + hexByte(picked.g * 255)
                    + hexByte(picked.b * 255)
        syncingColor = true
        colorInput.text = selectedAlpha < 255 ? "#" + hexByte(selectedAlpha) + rgb
                                              : "#" + rgb
        syncingColor = false
    }

    function syncPickerFromText() {
        if (syncingColor || !colorInput.acceptableInput)
            return

        const value = colorInput.text
        const hasAlpha = value.length === 9
        const offset = hasAlpha ? 3 : 1
        const alpha = hasAlpha ? parseInt(value.slice(1, 3), 16) : 255
        const red = parseInt(value.slice(offset, offset + 2), 16) / 255
        const green = parseInt(value.slice(offset + 2, offset + 4), 16) / 255
        const blue = parseInt(value.slice(offset + 4, offset + 6), 16) / 255
        const maximum = Math.max(red, green, blue)
        const minimum = Math.min(red, green, blue)
        const delta = maximum - minimum
        let hue = selectedHue

        if (delta > 0) {
            if (maximum === red)
                hue = ((green - blue) / delta) % 6
            else if (maximum === green)
                hue = (blue - red) / delta + 2
            else
                hue = (red - green) / delta + 4
            hue = ((hue / 6) + 1) % 1
        }

        selectedHue = hue
        selectedSaturation = maximum === 0 ? 0 : delta / maximum
        selectedValue = maximum
        selectedAlpha = alpha
        alphaSlider.value = alpha
        saturationValueCanvas.requestPaint()
        colorPreviewCanvas.requestPaint()
    }

    function openWithColor(colorValue) {
        colorInput.text = /^#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(colorValue)
                          ? colorValue.toUpperCase() : "#EEF7FF"
        syncPickerFromText()
        open()
    }

    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.surface
        border.color: Theme.outlineVariant
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialIcon {
                icon: "palette"
                iconSize: 28
                color: Theme.primary
            }
            Text {
                Layout.fillWidth: true
                text: "选择中栏颜色"
                color: Theme.textPrimary
                font.pixelSize: 22
                font.weight: Font.Bold
            }
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: closeMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "close"
                    iconSize: 22
                    color: Theme.textSecondary
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.reject()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 190
            radius: Theme.radiusLarge
            color: "transparent"
            clip: true

            Canvas {
                id: saturationValueCanvas
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = root.hueColor()
                    ctx.fillRect(0, 0, width, height)

                    const white = ctx.createLinearGradient(0, 0, width, 0)
                    white.addColorStop(0, "#FFFFFF")
                    white.addColorStop(1, "rgba(255, 255, 255, 0)")
                    ctx.fillStyle = white
                    ctx.fillRect(0, 0, width, height)

                    const black = ctx.createLinearGradient(0, 0, 0, height)
                    black.addColorStop(0, "rgba(0, 0, 0, 0)")
                    black.addColorStop(1, "#000000")
                    ctx.fillStyle = black
                    ctx.fillRect(0, 0, width, height)
                }
            }

            Rectangle {
                width: 20
                height: 20
                radius: 10
                x: root.selectedSaturation * (parent.width - width)
                y: (1 - root.selectedValue) * (parent.height - height)
                color: root.opaqueColor()
                border.width: 3
                border.color: "white"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor

                function selectAt(mouse) {
                    root.selectedSaturation = Math.max(0, Math.min(1, mouse.x / width))
                    root.selectedValue = 1 - Math.max(0, Math.min(1, mouse.y / height))
                    root.updateColorText()
                }

                onPressed: function(mouse) { selectAt(mouse) }
                onPositionChanged: function(mouse) {
                    if (pressed)
                        selectAt(mouse)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            radius: 9
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#FF0000" }
                GradientStop { position: 0.1667; color: "#FFFF00" }
                GradientStop { position: 0.3333; color: "#00FF00" }
                GradientStop { position: 0.5; color: "#00FFFF" }
                GradientStop { position: 0.6667; color: "#0000FF" }
                GradientStop { position: 0.8333; color: "#FF00FF" }
                GradientStop { position: 1.0; color: "#FF0000" }
            }

            Rectangle {
                width: 16
                height: 26
                radius: 8
                x: root.selectedHue * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                color: root.hueColor()
                border.width: 2
                border.color: "white"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                function selectAt(mouse) {
                    root.selectedHue = Math.max(0, Math.min(1, mouse.x / width))
                    saturationValueCanvas.requestPaint()
                    root.updateColorText()
                }

                onPressed: function(mouse) { selectAt(mouse) }
                onPositionChanged: function(mouse) {
                    if (pressed)
                        selectAt(mouse)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: Theme.radiusMedium
                color: Theme.surface
                border.color: Theme.outline
                border.width: 1

                Canvas {
                    id: colorPreviewCanvas
                    anchors.fill: parent
                    anchors.margins: 3
                    onPaint: {
                        const ctx = getContext("2d")
                        const cornerRadius = 9
                        const tile = 7
                        ctx.clearRect(0, 0, width, height)
                        ctx.save()
                        ctx.beginPath()
                        ctx.moveTo(cornerRadius, 0)
                        ctx.lineTo(width - cornerRadius, 0)
                        ctx.quadraticCurveTo(width, 0, width, cornerRadius)
                        ctx.lineTo(width, height - cornerRadius)
                        ctx.quadraticCurveTo(width, height, width - cornerRadius, height)
                        ctx.lineTo(cornerRadius, height)
                        ctx.quadraticCurveTo(0, height, 0, height - cornerRadius)
                        ctx.lineTo(0, cornerRadius)
                        ctx.quadraticCurveTo(0, 0, cornerRadius, 0)
                        ctx.closePath()
                        ctx.clip()

                        for (let y = 0; y < height; y += tile) {
                            for (let x = 0; x < width; x += tile) {
                                const even = (Math.floor(x / tile) + Math.floor(y / tile)) % 2 === 0
                                ctx.fillStyle = even ? "#FFFFFF" : "#D7D3DC"
                                ctx.fillRect(x, y, tile, tile)
                            }
                        }
                        if (colorInput.acceptableInput) {
                            ctx.fillStyle = colorInput.text
                            ctx.fillRect(0, 0, width, height)
                        }
                        ctx.restore()
                    }
                }
            }

            TextField {
                id: colorInput
                objectName: "middlePanelColorPickerInput"
                Layout.fillWidth: true
                implicitHeight: 52
                placeholderText: "#RRGGBB 或 #AARRGGBB"
                color: Theme.textPrimary
                font.family: "Cascadia Mono"
                font.pixelSize: 15
                leftPadding: 16
                rightPadding: 16
                validator: RegularExpressionValidator {
                    regularExpression: /#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})/
                }
                onTextChanged: {
                    root.syncPickerFromText()
                    colorPreviewCanvas.requestPaint()
                }
                background: Rectangle {
                    radius: Theme.radiusMedium
                    color: Theme.surfaceContainerLow
                    border.color: colorInput.activeFocus ? Theme.primary : Theme.outline
                    border.width: colorInput.activeFocus ? 2 : 1
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "透明度"
                color: Theme.textPrimary
                font.pixelSize: 14
            }
            Slider {
                id: alphaSlider
                Layout.fillWidth: true
                from: 0
                to: 255
                stepSize: 1
                value: 255
                onMoved: {
                    root.selectedAlpha = Math.round(value)
                    root.updateColorText()
                }
            }
            Text {
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
                text: root.selectedAlpha
                color: Theme.textSecondary
                font.pixelSize: 14
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }
            PrimaryButton {
                objectName: "middlePanelColorCancelButton"
                implicitWidth: 104
                implicitHeight: 48
                radius: 24
                text: "取消"
                iconName: ""
                tonal: true
                onClicked: root.reject()
            }
            PrimaryButton {
                objectName: "middlePanelColorConfirmButton"
                implicitWidth: 104
                implicitHeight: 48
                radius: 24
                text: "确定"
                iconName: "check"
                enabled: colorInput.acceptableInput
                onClicked: root.accept()
            }
        }
    }
}
