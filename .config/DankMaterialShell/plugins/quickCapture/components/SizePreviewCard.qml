import QtQuick
import qs.Common
import qs.Widgets
import qs.Modals.Common
import qs.Services
import "../dms-common"
import "Constants.js" as Constants

Rectangle {
    id: sizePreviewItem

    required property var window
    required property var drawingCanvas

    visible: window.showSizePreview
    x: window.previewX - (width / 2)
    y: window.previewY - (height / 2)

    readonly property bool _showShape: window.effectiveTool !== "spotlight"

    width: _showShape ? shapeWidth : 0
    height: width
    radius: _showShape ? shapeRadius : 0
    color: "transparent"
    border.color: _showShape ? shapeBorderColor : "transparent"
    border.width: _showShape ? 1.5 / drawingCanvas.scale : 0
    z: 20

    readonly property real shapeWidth: {
        let base = window.activeIntensity;
        const tool = window.effectiveTool;
        const meta = Constants.getToolMeta(tool);

        if (meta.previewFixedWidth !== undefined) {
            base = meta.previewFixedWidth;
        } else if (meta.previewMultiplier) {
            base = window.activeIntensity * meta.previewMultiplier;
        }
        if (meta.previewClampMin !== undefined) {
            base = Math.max(meta.previewClampMin, Math.min(meta.previewClampMax, base));
        }

        if (tool === "callout") {
            if (window.currentTool === "select" && !window.calloutDestDragging && window.selectedStroke) {
                const bw = window.selectedStroke.borderWidth !== undefined ? window.selectedStroke.borderWidth : 2;
                base = bw * 2;
            }
        }
        return base * window.editScale;
    }
    readonly property real shapeRadius: {
        const tool = window.effectiveTool;
        if (tool === "highlighter") return window.roundHighlighter ? shapeWidth / 2 : 0;
        if (tool === "spotlight" || tool === "rect" || tool === "redact") return window.roundRect ? (Theme.cornerRadius * window.editScale) : 0;
        if (tool === "pixelate" || tool === "text") return 0;
        if (tool === "callout") {
            if (window.currentTool === "select" && !window.calloutDestDragging && window.selectedStroke) {
                return shapeWidth / 2;
            }
            return 0;
        }
        return shapeWidth / 2;
    }
    readonly property color shapeBorderColor: {
        if (window.effectiveTool === "callout") {
            if (window.currentTool === "select" && !window.calloutDestDragging && window.selectedStroke) {
                return Theme.primary;
            }
            return "transparent";
        }
        if (window.currentTool === "select" && window.selectedStroke && window.selectedStroke.tool === "stamp") {
            return "transparent";
        }
        return Theme.primary;
    }

    StyledText {
        id: valueLabel
        anchors.top: parent.bottom
        anchors.topMargin: 16 / drawingCanvas.scale
        anchors.horizontalCenter: parent.horizontalCenter
        text: {
            if (window.currentTool === "select" && window.selectedStroke && window.selectedStroke.tool === "callout") {
                if (window.calloutDestDragging) {
                    return window.selectedStroke.width + "%";
                } else {
                    const bw = window.selectedStroke.borderWidth !== undefined ? window.selectedStroke.borderWidth : 2;
                    return bw + "px";
                }
            }
            const tool = window.effectiveTool;
            const meta = Constants.getToolMeta(tool);
            return window.activeIntensity + meta.unit;
        }

        color: Theme.primary
        font.pixelSize: 10 / drawingCanvas.scale
        font.bold: true
    }
}
