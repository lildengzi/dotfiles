import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modals.Common
import qs.Services
import "./dms-common"
import "components"
import "components/Helpers.js" as Helpers
import "components/DrawingRenderer.js" as DrawingRenderer
import "components/Constants.js" as Constants

DankModal {
    id: window

    readonly property var rootWindow: window

    CaptureConfig { 
        id: config 
        pluginData: (window.parentWidget && window.parentWidget.pluginData) ? window.parentWidget.pluginData : ({})
        onPluginDataChanged: window.loadPresetsFromPluginData()
    }

    Image {
        id: watermarkImageLoader
        
        source: {
            const rawPath = (window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.watermarkImage) ? window.parentWidget.pluginData.watermarkImage : "";
            if (rawPath) {
                let p = rawPath.trim();
                if (p.indexOf("~/") === 0) {
                    const home = Quickshell.env("HOME") || "";
                    p = home + p.substring(1);
                }
                if (p.indexOf("/") === 0) {
                    p = `file://${p}`;
                }
                return p;
            }
            return "";
        }
        
        visible: false
        cache: true
    }

    layerNamespace: "dms:plugins:quickCapture"
    keepPopoutsOpen: true

    // Parent communication reference
    property var parentWidget: null

    // State Variables
    property var paletteWarningDialogRef: null
    property var toolbarItem: null
    property int activeColorSlotIndex: 0
    property color pendingColorToSave: "transparent"
    property int pendingSlotToSave: -1
    property string currentTool: "crop" // crop, select, pen, line, arrow, rect, ellipse, text, pixelate, redact, stamp, highlighter, eraser, spotlight, backdrop
    property string lastActiveTool: "pen"
    property string colorPickerMode: "draw" // draw, copy
    property color hoveredColor: "transparent"

    function requestActiveCanvasPaint() {
        if (window.activeCanvas) {
            window.activeCanvas.requestPaint();
        }
    }

    function refreshStrokeReference(stroke) {
        const idx = window.strokes.indexOf(stroke);
        if (idx !== -1) {
            window.strokes[idx] = stroke;
            window.strokes = [...window.strokes];
        }
    }

    function copyStrokePoints(points) {
        const copied = [];
        for (let p of points) {
            copied.push(Qt.point(p.x, p.y));
        }
        return copied;
    }

    function updateToolStrokeState(tool, updater) {
        if (window.selectedStroke && window.selectedStroke.tool === tool) {
            updater(window.selectedStroke);
            window.refreshStrokeReference(window.selectedStroke);
        }
        if (window.currentStroke && window.currentStroke.tool === tool) {
            updater(window.currentStroke);
        }
        window.requestActiveCanvasPaint();
    }

    function syncStyleFromStroke(stroke) {
        window.currentColor = stroke.color;
        if (stroke.tool === "text") window.textFontSize = stroke.width;
        else if (stroke.tool === "pixelate") window.pixelateIntensity = stroke.width;
        else if (stroke.tool === "spotlight") window.spotlightIntensity = stroke.width;
        else if (stroke.tool === "callout") window.calloutZoom = stroke.width;
        else window.strokeWidth = stroke.width;

        if (stroke.tool === "line" && stroke.lineStyle) window.activeLineStyle = stroke.lineStyle;
        if (stroke.tool === "arrow") {
            if (stroke.arrowLineStyle) window.activeArrowLineStyle = stroke.arrowLineStyle;
            if (stroke.arrowHeadStyle) window.activeArrowHeadStyle = stroke.arrowHeadStyle;
        }
        if (stroke.tool === "redact" && stroke.redactMode) window.activeRedactMode = stroke.redactMode;
        if (stroke.tool === "redact" && stroke.redactShape) window.activeRedactShape = stroke.redactShape;
        if (stroke.tool === "callout") {
            window.calloutLinkLines = stroke.calloutLinkLines !== undefined ? stroke.calloutLinkLines : 1;
            window.calloutShape = stroke.calloutShape !== undefined ? stroke.calloutShape : "rect";
        }
    }

    function bringStrokeToFront(stroke) {
        const reorder = [...window.strokes];
        const idx = reorder.indexOf(stroke);
        if (idx !== -1) {
            reorder.splice(idx, 1);
            reorder.push(stroke);
            window.strokes = reorder;
        }
    }

    function selectStrokeForEditing(stroke, saveCurrentState) {
        if (saveCurrentState) {
            window.savePreGrabState();
        }
        window.selectedStroke = stroke;
        window.originalPoints = window.copyStrokePoints(stroke.points);
        window.syncStyleFromStroke(stroke);
        window.bringStrokeToFront(stroke);
    }

    function deselectStrokeForEditing(restoreStyle) {
        window.selectedStroke = null;
        window.originalPoints = [];
        window.activeHandle = "none";
        window.calloutDestDragging = false;
        if (restoreStyle) {
            window.restorePreGrabState();
        }
    }

    function enterColorPickerTool() {
        window._lastSampledX = -1;
        window._lastSampledY = -1;
        window._lastSampledColor = "transparent";
        window.requestPaintAll();
        window.hoveredColor = window.sampleCanvasColor(window.cursorX * window.editScale, window.cursorY * window.editScale);
    }

    function enterBackdropTool() {
        if (window.backdropMode !== "none") return;
        const defaultMode = (config && config.pluginData && config.pluginData["backdropDefaultMode"]) || Constants.defaultBackdropMode;
        window.backdropMode = defaultMode;
    }

    function enterSelectTool() {
        if (window.selectedStroke || window.strokes.length === 0) return;
        window.selectStrokeForEditing(window.strokes[window.strokes.length - 1], true);
    }

    function handleCurrentToolChanged() {
        if (window.currentTool !== "colorpicker") {
            window.backdropColorPickingSlot = "none";
        }
        if (window.currentTool !== "text" && window.isTyping) {
            window.commitTypingText();
        }
        if (window.currentTool !== "crop" && window.currentTool !== "backdrop" && window.currentTool !== "select" && window.currentTool !== "colorpicker") {
            window.lastActiveTool = window.currentTool;
        }
        if (window.currentTool !== "select" && window.selectedStroke) {
            window.deselectStrokeForEditing(true);
            window.requestActiveCanvasPaint();
        }
        if (window.currentTool === "colorpicker") {
            window.enterColorPickerTool();
        }
        if (window.currentTool === "backdrop") {
            window.enterBackdropTool();
        }
        if (window.currentTool === "select") {
            window.enterSelectTool();
        }
        window.requestPaintAll();
    }

    property string activeLineStyle: "solid"
    property string activeRedactMode: "solid" // solid, blur, clean
    onActiveRedactModeChanged: {
        window.updateToolStrokeState("redact", function(stroke) {
            stroke.redactMode = window.activeRedactMode;
            stroke.cachedCleanColor = undefined;
        });
    }
    property string activeRedactShape: window.roundRect ? "roundRect" : "rect" // rect, roundRect, ellipse
    onActiveRedactShapeChanged: {
        window.updateToolStrokeState("redact", function(stroke) {
            stroke.redactShape = window.activeRedactShape;
            stroke.cachedCleanColor = undefined;
        });
    }
    onActiveLineStyleChanged: {
        window.updateToolStrokeState("line", function(stroke) {
            stroke.lineStyle = window.activeLineStyle;
        });
    }
    property string activeArrowLineStyle: "solid"
    property string activeArrowHeadStyle: "single-filled"
    onActiveArrowLineStyleChanged: {
        window.updateToolStrokeState("arrow", function(stroke) {
            stroke.arrowLineStyle = window.activeArrowLineStyle;
        });
    }
    onActiveArrowHeadStyleChanged: {
        window.updateToolStrokeState("arrow", function(stroke) {
            stroke.arrowHeadStyle = window.activeArrowHeadStyle;
        });
    }
    property int _lastSampledX: -1
    property int _lastSampledY: -1
    property color _lastSampledColor: "transparent"
    readonly property real dpr: Screen.devicePixelRatio || 1.0
    onCurrentToolChanged: {
        window.handleCurrentToolChanged();
    }

    // Backdrop State Variables
    property string backdropMode: "none" // none, solid, gradient
    property color backdropSolidColor: Theme.primary
    property color backdropGradientStart: Theme.primary
    property color backdropGradientEnd: Theme.secondary
    property int backdropGradientAngle: Constants.defaultBackdropGradientAngle
    property int backdropPadding: Constants.defaultBackdropPadding
    property int backdropCornerRadius: Constants.defaultBackdropCornerRadius
    property int backdropShadowStrength: Constants.defaultBackdropShadowStrength
    property string backdropAspectRatio: "auto"
    property real customAspectRatio: 1.50
    property string backdropAlignment: "center"
    property string backdropColorPickingSlot: "none" // none, solid, start, end
    readonly property real customRatioMin: 0.50
    readonly property real customRatioMax: 2.50
    readonly property var aspectPresets: [
        { value: "auto", label: I18n.tr("AUTO") },
        { value: "1:1", label: "1:1" },
        { value: "16:9", label: "16:9" },
        { value: "9:16", label: "9:16" },
        { value: "4:3", label: "4:3" },
        { value: "3:2", label: "3:2" },
        { value: "21:9", label: "21:9" },
        { value: "custom", label: I18n.tr("CUST") }
    ]
    property bool hasUserCustomizedBackdrop: false
    property color autoBackdropGradientStart: Theme.primary
    property color autoBackdropGradientEnd: Theme.secondary
    property color autoBackdropSolidColor: Theme.primary
    property var customBackdropPresets: []
    property var hiddenPresetIds: []
    readonly property var backdropPresets: {
        var customMap = {};
        if (customBackdropPresets) {
            for (var i = 0; i < customBackdropPresets.length; i++) {
                var cp = customBackdropPresets[i];
                customMap[cp.id] = cp;
            }
        }

        var list = [];
        if (Constants && Constants.defaultBackdropPresets) {
            for (var j = 0; j < Constants.defaultBackdropPresets.length; j++) {
                var dp = Constants.defaultBackdropPresets[j];
                if (!hiddenPresetIds || hiddenPresetIds.indexOf(dp.id) === -1) {
                    if (customMap[dp.id]) {
                        list.push(customMap[dp.id]);
                    } else {
                        list.push(dp);
                    }
                }
            }
        }
        if (customBackdropPresets) {
            for (var k = 0; k < customBackdropPresets.length; k++) {
                var up = customBackdropPresets[k];
                if (up.isCustomUserCreated && (!hiddenPresetIds || hiddenPresetIds.indexOf(up.id) === -1)) {
                    list.push(up);
                }
            }
        }
        return list;
    }

    // Intensity Management
    property real penSmoothingAlpha: 0.4
    property int strokeWidth: 8
    property int pixelateIntensity: 8

    property int spotlightIntensity: 50
    onSpotlightIntensityChanged: {
        preGrabSpotlightIntensity = spotlightIntensity;
        for (let i = 0; i < window.strokes.length; i++) {
            if (window.strokes[i].tool === "spotlight") {
                window.strokes[i].width = window.spotlightIntensity;
            }
        }
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property var undoneStrokes: []
    readonly property bool canUndo: strokes.length > 0
    readonly property bool canRedo: undoneStrokes.length > 0
    property int textFontSize: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.textFontSize !== undefined ? window.parentWidget.pluginData.textFontSize : 36
    property int calloutZoom: 150
    property bool calloutDestDragging: false

    readonly property string effectiveTool: (pastePreviewActive && copiedStroke) ? copiedStroke.tool : ((currentTool === "select" && selectedStroke) ? selectedStroke.tool : currentTool)
    readonly property bool hasActiveCropSelection: window.currentTool !== "crop" && window.hasSelection
    property int activeIntensity: {
        if (pastePreviewActive && copiedStroke && copiedStroke.width !== undefined) return copiedStroke.width;
        if (effectiveTool === "text") return textFontSize;
        if (effectiveTool === "pixelate") return pixelateIntensity;
        if (effectiveTool === "spotlight") return spotlightIntensity;
        if (effectiveTool === "callout") return calloutZoom;
        return strokeWidth;
    }

    function updateCalloutDestFromWidth(stroke, width) {
        if (!stroke || stroke.tool !== "callout" || !stroke.points || stroke.points.length !== 4) return;

        const srcP0 = stroke.points[0];
        const srcP1 = stroke.points[1];
        const dstP0 = stroke.points[2];
        const rw = srcP1.x - srcP0.x;
        const rh = srcP1.y - srcP0.y;
        const zoom = width / 100.0;
        const newPoints = [...stroke.points];
        newPoints[3] = Qt.point(dstP0.x + rw * zoom, dstP0.y + rh * zoom);
        stroke.points = newPoints;
    }

    function updatePastePreviewWidth(width) {
        if (!window.pastePreviewActive || !window.copiedStroke) return false;

        const nextStroke = Object.assign({}, window.copiedStroke, { width: width });
        if (nextStroke.tool === "redact") {
            nextStroke.cachedCleanColor = undefined;
        }
        window.updateCalloutDestFromWidth(nextStroke, width);
        window.copiedStroke = nextStroke;
        window.repaintActiveCanvas();
        return true;
    }

    function updatePastePreviewColor(color) {
        if (!window.pastePreviewActive || !window.copiedStroke) return false;

        const nextStroke = Object.assign({}, window.copiedStroke, { color: color.toString() });
        if (nextStroke.tool === "redact") {
            nextStroke.cachedCleanColor = undefined;
        }
        window.copiedStroke = nextStroke;
        window.repaintActiveCanvas();
        return true;
    }

    function updateActiveIntensity(val) {
        const meta = Constants.getToolMeta(effectiveTool);
        const clamped = Math.max(meta.min, Math.min(meta.max, val));

        if (effectiveTool === "text") textFontSize = clamped;
        else if (effectiveTool === "pixelate") pixelateIntensity = clamped;
        else if (effectiveTool === "spotlight") {
            spotlightIntensity = clamped;
            preGrabSpotlightIntensity = clamped;
        }
        else if (effectiveTool === "callout") calloutZoom = clamped;
        else strokeWidth = clamped;

        if (window.updatePastePreviewWidth(clamped)) return;

        if (selectedStroke) {
            selectedStroke.width = clamped;
            window.updateCalloutDestFromWidth(selectedStroke, clamped);
            const idx = window.strokes.indexOf(selectedStroke);
            if (idx !== -1) {
                window.strokes[idx] = selectedStroke;
                window.strokes = [...window.strokes];
            }
        }
        if (currentStroke) {
            currentStroke.width = clamped;
        }
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }

    property color currentColor: Theme.primary
    onCurrentColorChanged: {
        if (window.updatePastePreviewColor(window.currentColor)) {
            return;
        }
        if (window.selectedStroke) {
            window.selectedStroke.color = window.currentColor.toString();
            if (window.selectedStroke.tool === "redact") {
                window.selectedStroke.cachedCleanColor = undefined;
            }
            const idx = window.strokes.indexOf(window.selectedStroke);
            if (idx !== -1) {
                window.strokes[idx] = window.selectedStroke;
                window.strokes = [...window.strokes];
            }
        }
        if (window.currentStroke) {
            window.currentStroke.color = window.currentColor.toString();
        }
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property int stampCounter: 1
    property int stampIdCounter: 1
    property string stampCounterFormat: "numeric" // numeric, alpha, roman
    onStampCounterFormatChanged: {
        window.reindexStamps();
        window.requestPaintAll();
    }
    property string calloutShape: "rect" // rect, ellipse
    onCalloutShapeChanged: {
        if (selectedStroke && selectedStroke.tool === "callout") {
            if (selectedStroke.calloutShape !== calloutShape) {
                selectedStroke.calloutShape = calloutShape;
                const idx = window.strokes.indexOf(selectedStroke);
                if (idx !== -1) {
                    window.strokes[idx] = selectedStroke;
                    window.strokes = [...window.strokes];
                }
                if (window.activeCanvas) window.activeCanvas.requestPaint();
            }
        }
    }
    property int calloutLinkLines: 1 // 1, 2
    onCalloutLinkLinesChanged: {
        if (selectedStroke && selectedStroke.tool === "callout") {
            if (selectedStroke.calloutLinkLines !== calloutLinkLines) {
                selectedStroke.calloutLinkLines = calloutLinkLines;
                const idx = window.strokes.indexOf(selectedStroke);
                if (idx !== -1) {
                    window.strokes[idx] = selectedStroke;
                    window.strokes = [...window.strokes];
                }
                if (window.activeCanvas) window.activeCanvas.requestPaint();
            }
        }
    }
    property bool isScreenshotDark: false
    property bool hasSampledContrast: false
    property real previewX: 0
    property real previewY: 0
    property bool showSizePreview: false


    // --- Proxy Editing Optimization ---
    readonly property real maxEditDimension: {
        const q = (window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.editQuality) || String(Constants.defaultEditQuality);
        if (q === "original") return Infinity;
        const val = parseInt(q);
        return (isNaN(val) || val <= 0) ? Constants.defaultEditQuality : val;
    }
    readonly property real editScale: {
        if (!window.bgImageItem) return 1.0;
        // When backdrop is active, render at screen resolution for sharp preview
        if (window.effectiveBackdropMode !== "none") return Math.max(1e-3, window.fitScale);
        const w = window.bgImageItem.sourceSize.width;
        const h = window.bgImageItem.sourceSize.height;
        const max = Math.max(w, h);
        let baseScale = 1.0;
        if (!(isNaN(max) || max <= 0 || max <= maxEditDimension)) {
            baseScale = maxEditDimension / max;
        }
        // Cap the editScale to fitScale so that the canvas resolution
        // never exceeds the actual display size on the screen.
        const maxRequiredScale = window.fitScale;
        return Math.min(baseScale, maxRequiredScale);
    }

    readonly property string effectiveBackdropMode: window.currentTool === "crop" ? "none" : window.backdropMode

    readonly property real screenshotWidth: {
        if (window.hasActiveCropSelection) {
            return window.cropRect.width;
        }
        if (!window.bgImageItem) return 1;
        return (window.bgRotation % 180 === 0) ? window.bgImageItem.sourceSize.width : window.bgImageItem.sourceSize.height;
    }
    readonly property real screenshotHeight: {
        if (window.hasActiveCropSelection) {
            return window.cropRect.height;
        }
        if (!window.bgImageItem) return 1;
        return (window.bgRotation % 180 === 0) ? window.bgImageItem.sourceSize.height : window.bgImageItem.sourceSize.width;
    }

    function getTargetRatio(ratioStr) {
        if (ratioStr === "auto") return 0.0;
        if (ratioStr === "1:1") return 1.0;
        if (ratioStr === "16:9") return 16.0 / 9.0;
        if (ratioStr === "9:16") return 9.0 / 16.0;
        if (ratioStr === "4:3") return 4.0 / 3.0;
        if (ratioStr === "3:2") return 3.0 / 2.0;
        if (ratioStr === "21:9") return 21.0 / 9.0;
        if (ratioStr === "custom") {
            const val = window.customAspectRatio;
            return (isFinite(val) && val > 0) ? val : 1.0;
        }
        return 0.0;
    }

    readonly property real canvasWidth: {
        if (window.effectiveBackdropMode === "none") {
            return screenshotWidth;
        }
        const baseW = screenshotWidth + 2 * window.backdropPadding;
        const baseH = screenshotHeight + 2 * window.backdropPadding;
        if (window.backdropAspectRatio === "auto") {
            return baseW;
        }
        const targetRatio = getTargetRatio(window.backdropAspectRatio);
        if (!(targetRatio > 0.0)) {
            return baseW;
        }
        const currentRatio = baseW / baseH;
        if (currentRatio > targetRatio) {
            return baseW;
        } else {
            return baseH * targetRatio;
        }
    }

    readonly property real canvasHeight: {
        if (window.effectiveBackdropMode === "none") {
            return screenshotHeight;
        }
        const baseW = screenshotWidth + 2 * window.backdropPadding;
        const baseH = screenshotHeight + 2 * window.backdropPadding;
        if (window.backdropAspectRatio === "auto") {
            return baseH;
        }
        const targetRatio = getTargetRatio(window.backdropAspectRatio);
        if (!(targetRatio > 0.0)) {
            return baseH;
        }
        const currentRatio = baseW / baseH;
        if (currentRatio > targetRatio) {
            return baseW / targetRatio;
        } else {
            return baseH;
        }
    }

    readonly property real backdropScaleFactor: 1.0

    readonly property real screenshotXOffset: {
        if (window.effectiveBackdropMode === "none") return 0;
        const align = window.backdropAlignment;
        if (align.endsWith("-left"))  return 0;
        if (align.endsWith("-right")) return canvasWidth - screenshotWidth;
        return (canvasWidth - screenshotWidth) / 2;
    }
    readonly property real screenshotYOffset: {
        if (window.effectiveBackdropMode === "none") return 0;
        const align = window.backdropAlignment;
        if (align.startsWith("top-"))    return 0;
        if (align.startsWith("bottom-")) return canvasHeight - screenshotHeight;
        return (canvasHeight - screenshotHeight) / 2;
    }

    function drawBackdropBackground(ctx, w, h) {
        if (window.backdropMode === "solid") {
            ctx.fillStyle = window.backdropSolidColor.toString();
            ctx.fillRect(0, 0, w, h);
        } else if (window.backdropMode === "gradient") {
            const angleRad = (window.backdropGradientAngle * Math.PI) / 180;
            const x1 = w / 2 - Math.cos(angleRad) * w / 2;
            const y1 = h / 2 - Math.sin(angleRad) * h / 2;
            const x2 = w / 2 + Math.cos(angleRad) * w / 2;
            const y2 = h / 2 + Math.sin(angleRad) * h / 2;
            const grad = ctx.createLinearGradient(x1, y1, x2, y2);
            grad.addColorStop(0, window.backdropGradientStart.toString());
            grad.addColorStop(1, window.backdropGradientEnd.toString());
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, w, h);
        } else if (window.backdropMode === "radial") {
            const cx = w / 2;
            const cy = h / 2;
            const r = Math.hypot(cx, cy);
            const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
            grad.addColorStop(0, window.backdropGradientStart.toString());
            grad.addColorStop(1, window.backdropGradientEnd.toString());
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, w, h);
        } else if (window.backdropMode === "conic") {
            const cx = w / 2;
            const cy = h / 2;
            const r = Math.hypot(cx, cy);
            const startAngle = (window.backdropGradientAngle * Math.PI) / 180;
            const numSlices = 240;

            // Cache color components to avoid JS-to-C++ property boundary crossing cost
            const startCol = window.backdropGradientStart;
            const endCol = window.backdropGradientEnd;
            const sr = startCol.r * 255;
            const sg = startCol.g * 255;
            const sb = startCol.b * 255;
            const sa = startCol.a;
            const er = endCol.r * 255;
            const eg = endCol.g * 255;
            const eb = endCol.b * 255;
            const ea = endCol.a;

            ctx.save();
            ctx.translate(cx, cy);
            for (let i = 0; i < numSlices; i++) {
                const angle1 = startAngle + (i / numSlices) * Math.PI * 2;
                const angle2 = startAngle + ((i + 1.01) / numSlices) * Math.PI * 2;
                const t = i / numSlices;
                const rComp = Math.round(sr * (1 - t) + er * t);
                const gComp = Math.round(sg * (1 - t) + eg * t);
                const bComp = Math.round(sb * (1 - t) + eb * t);
                const aComp = sa * (1 - t) + ea * t;
                ctx.fillStyle = `rgba(${rComp},${gComp},${bComp},${aComp})`;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.arc(0, 0, r, angle1, angle2);
                ctx.closePath();
                ctx.fill();
            }
            ctx.restore();
        }
    }

    function getScreenshotLayout() {
        const factor = window.backdropScaleFactor;
        return {
            x: window.screenshotXOffset,
            y: window.screenshotYOffset,
            w: window.screenshotWidth * factor,
            h: window.screenshotHeight * factor,
            r: window.backdropCornerRadius * factor
        };
    }

    function drawScreenshotShadow(ctx, scale) {
        if (window.backdropShadowStrength <= 0) return;
        ctx.save();
        const layout = window.getScreenshotLayout();
        const r = layout.r;
        const x = layout.x;
        const y = layout.y;
        const w = layout.w;
        const h = layout.h;
        
        const s = (scale !== undefined && scale > 0) ? scale : 1.0;
        const opacity = (window.backdropShadowStrength / 100.0) * Constants.shadowBaseOpacityFactor;
        const STEPS = Constants.defaultShadowSteps;
        
        // Proportional shadow bounds for small layouts
        const baseBlur = Math.min(Constants.maxShadowBlur, Math.min(w, h) * 0.15);
        const baseOffset = Math.min(Constants.maxShadowOffset, Math.min(w, h) * 0.08);
        
        const maxOffset = baseOffset / s;
        const maxBlur = baseBlur / s;
        
        // Draw 12 concentric shadow layers with quadratic spacing and falloff for smooth rendering
        for (let i = 1; i <= STEPS; i++) {
            const t = i / STEPS;
            const blur = Math.pow(t, 1.5) * maxBlur;
            const offset = Math.pow(t, 1.5) * maxOffset;
            const alpha = opacity * Math.pow(1.0 - t, 1.5) * 0.75;
            
            ctx.fillStyle = Qt.rgba(0, 0, 0, alpha);
            
            const sx = x - blur/2;
            const sy = y - blur/2 + offset;
            const sw = w + blur;
            const sh = h + blur;
            const sr = r + blur/2;
            
            ctx.beginPath();
            if (sr > 0) {
                ctx.moveTo(sx + sr, sy);
                ctx.lineTo(sx + sw - sr, sy);
                ctx.arcTo(sx + sw, sy, sx + sw, sy + sr, sr);
                ctx.lineTo(sx + sw, sy + sh - sr);
                ctx.arcTo(sx + sw, sy + sh, sx + sw - sr, sy + sh, sr);
                ctx.lineTo(sx + sr, sy + sh);
                ctx.arcTo(sx, sy + sh, sx, sy + sh - sr, sr);
                ctx.lineTo(sx, sy + sr);
                ctx.arcTo(sx, sy, sx + sr, sy, sr);
            } else {
                ctx.rect(sx, sy, sw, sh);
            }
            ctx.closePath();
            ctx.fill();
        }
        ctx.restore();
    }

    function drawScreenshotImage(ctx, imgSource) {
        if (!imgSource || imgSource.status !== Image.Ready) return;
        ctx.save();
        ctx.imageSmoothingEnabled = true;
        if (ctx.imageSmoothingQuality !== undefined) {
            ctx.imageSmoothingQuality = "high";
        }
        
        const layout = window.getScreenshotLayout();
        const r = layout.r;
        const x = layout.x;
        const y = layout.y;
        const w = layout.w;
        const h = layout.h;
        
        ctx.beginPath();
        if (r > 0) {
            ctx.moveTo(x + r, y);
            ctx.lineTo(x + w - r, y);
            ctx.arcTo(x + w, y, x + w, y + r, r);
            ctx.lineTo(x + w, y + h - r);
            ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
            ctx.lineTo(x + r, y + h);
            ctx.arcTo(x, y + h, x, y + h - r, r);
            ctx.lineTo(x, y + r);
            ctx.arcTo(x, y, x + r, y, r);
        } else {
            ctx.rect(x, y, w, h);
        }
        ctx.closePath();
        ctx.clip();
        
        const rawW = imgSource.sourceSize.width;
        const rawH = imgSource.sourceSize.height;
        const isRotated90 = (window.bgRotation === 90 || window.bgRotation === 270);
        const uncroppedW = isRotated90 ? rawH : rawW;
        const uncroppedH = isRotated90 ? rawW : rawH;

        if (window.hasSelection) {
            ctx.translate(-window.cropRect.x, -window.cropRect.y);
        }

        ctx.translate(x + uncroppedW / 2, y + uncroppedH / 2);
        if (window.bgRotation !== 0) {
            ctx.rotate(window.bgRotation * Math.PI / 180);
        }
        const sx = window.bgFlipH ? -1 : 1;
        const sy = window.bgFlipV ? -1 : 1;
        if (sx !== 1 || sy !== 1) {
            ctx.scale(sx, sy);
        }

        ctx.drawImage(imgSource, -rawW / 2, -rawH / 2, rawW, rawH);
        ctx.restore();
    }

    property bool isZoomPressed: false
    property real cursorX: 0
    property real cursorY: 0

    property bool showAnnotations: true
    onShowAnnotationsChanged: {
        window.requestPaintAll();
    }
    property var copiedStroke: null
    property bool pastePreviewActive: false

    property var strokes: []
    onStrokesChanged: {
        window.reindexStamps();
        window.requestPaintAll();
    }
    readonly property bool hasSpotlights: {
        for (let i = 0; i < strokes.length; i++) {
            if (strokes[i].tool === "spotlight") return true;
        }
        return false;
    }
    property var currentStroke: null
    onCurrentStrokeChanged: {
        if (window.bakedCanvas) window.bakedCanvas.requestPaint();
    }
    property var selectedStroke: null
    property int preGrabStrokeWidth: 8
    property int preGrabTextFontSize: 36
    property int preGrabPixelateIntensity: 8
    property int preGrabSpotlightIntensity: 50
    property int preGrabCalloutZoom: 150
    property color preGrabColor: Theme.primary
    property string preGrabRedactMode: "solid"
    property string preGrabRedactShape: "rect"
    property int preGrabCalloutLinkLines: 1
    property string preGrabCalloutShape: "rect"

    function savePreGrabState() {
        window.preGrabStrokeWidth = window.strokeWidth;
        window.preGrabTextFontSize = window.textFontSize;
        window.preGrabPixelateIntensity = window.pixelateIntensity;
        window.preGrabSpotlightIntensity = window.spotlightIntensity;
        window.preGrabCalloutZoom = window.calloutZoom;
        window.preGrabColor = window.currentColor;
        window.preGrabRedactMode = window.activeRedactMode;
        window.preGrabRedactShape = window.activeRedactShape;
        window.preGrabCalloutLinkLines = window.calloutLinkLines;
        window.preGrabCalloutShape = window.calloutShape;
    }

    function restorePreGrabState() {
        const restoreColor = window.preGrabColor;
        window.strokeWidth = window.preGrabStrokeWidth;
        window.textFontSize = window.preGrabTextFontSize;
        window.pixelateIntensity = window.preGrabPixelateIntensity;
        window.spotlightIntensity = window.preGrabSpotlightIntensity;
        window.calloutZoom = window.preGrabCalloutZoom;
        window.currentColor = restoreColor;
        window.activeRedactMode = window.preGrabRedactMode;
        window.activeRedactShape = window.preGrabRedactShape;
        window.calloutLinkLines = window.preGrabCalloutLinkLines;
        window.calloutShape = window.preGrabCalloutShape;
    }
    property point pressCoords: Qt.point(0, 0)
    property var originalPoints: []

    // Text Input Management
    property bool isTyping: false
    onIsTypingChanged: {
        if (isTyping) {
            typingCursorVisible = true;
        }
    }
    property point typingCoords: Qt.point(0,0)
    property string currentTypingText: ""
    property int typingCursorIndex: 0
    property bool typingCursorVisible: true
    property var editingStroke: null
    property bool typingIsSpeechBubble: false
    property point typingTargetCoords: Qt.point(0,0)

    Timer {
        id: typingCursorTimer
        interval: 500
        repeat: true
        running: window.isTyping
        onTriggered: {
            window.typingCursorVisible = !window.typingCursorVisible;
            if (window.activeCanvas) window.activeCanvas.requestPaint();
        }
    }

    backgroundOpacity: {
        const data = window.parentWidget && window.parentWidget.pluginData;
        if (!data) return 0.6;
        if (data.overlayOpacity !== undefined) return data.overlayOpacity / 100;
        if (data.modalOpacity !== undefined) return data.modalOpacity / 100;
        return 0.6;
    }
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)

    readonly property var pluginData: (window.parentWidget && window.parentWidget.pluginData) ? window.parentWidget.pluginData : ({})

    readonly property bool textMonospace: pluginData.textMonospace !== undefined ? pluginData.textMonospace : false
    
    // Rich Text Options
    property bool textBold: pluginData.textBold !== undefined ? pluginData.textBold : false
    onTextBoldChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property bool textItalic: pluginData.textItalic !== undefined ? pluginData.textItalic : false
    onTextItalicChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property bool textUnderline: pluginData.textUnderline !== undefined ? pluginData.textUnderline : false
    onTextUnderlineChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property bool textBackground: pluginData.textBackground !== undefined ? pluginData.textBackground : false
    onTextBackgroundChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property int textCornerRadius: pluginData.textCornerRadius !== undefined ? pluginData.textCornerRadius : 8
    onTextCornerRadiusChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property string textFontFamily: (pluginData.textFontFamily && pluginData.textFontFamily !== "system") ? pluginData.textFontFamily : (textMonospace ? "monospace" : (Theme.fontFamily || "sans-serif"))
    onTextFontFamilyChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property string stampFontFamily: (pluginData.stampFontFamily && pluginData.stampFontFamily !== "system") ? pluginData.stampFontFamily : (Theme.fontFamily || "sans-serif")
    onStampFontFamilyChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    readonly property string textInputMode: pluginData.textInputMode !== undefined ? pluginData.textInputMode : "inline"
    readonly property string toolbarPosition: pluginData.toolbarPosition !== undefined ? pluginData.toolbarPosition : "bottom"
    readonly property bool configShowToolbar: pluginData.showToolbar !== undefined ? pluginData.showToolbar : true
    readonly property bool enableMagnifier: true
    property bool toolbarVisible: true
    onConfigShowToolbarChanged: {
        window.toolbarVisible = window.configShowToolbar;
    }

    function rotateScreenshot(direction) {
        const isLeft = (direction === "left");
        const rawW = window.bgImageItem ? window.bgImageItem.sourceSize.width : 1;
        const rawH = window.bgImageItem ? window.bgImageItem.sourceSize.height : 1;
        const isRotated90 = (window.bgRotation === 90 || window.bgRotation === 270);
        const uncroppedW = isRotated90 ? rawH : rawW;
        const uncroppedH = isRotated90 ? rawW : rawH;

        if (window.hasSelection) {
            const cx = window.cropRect.x;
            const cy = window.cropRect.y;
            const cw = window.cropRect.width;
            const ch = window.cropRect.height;
            if (isLeft) {
                window.cropRect = Qt.rect(cy, uncroppedW - (cx + cw), ch, cw);
            } else {
                window.cropRect = Qt.rect(uncroppedH - (cy + ch), cx, ch, cw);
            }
        }

        const list = [...window.strokes];
        for (let s of list) {
            if (s.points) {
                s.points = s.points.map(p => ({
                    x: isLeft ? p.y : uncroppedH - p.y,
                    y: isLeft ? uncroppedW - p.x : p.x
                }));
            }
        }
        window.strokes = list;
        window.bgRotation = (window.bgRotation + (isLeft ? 270 : 90)) % 360;
        window.requestPaintAll();
    }

    function mirrorScreenshot(direction) {
        const isVertical = (direction === "vertical" || direction === "v");
        const rawW = window.bgImageItem ? window.bgImageItem.sourceSize.width : 1;
        const rawH = window.bgImageItem ? window.bgImageItem.sourceSize.height : 1;
        const isRotated90 = (window.bgRotation === 90 || window.bgRotation === 270);
        const uncroppedW = isRotated90 ? rawH : rawW;
        const uncroppedH = isRotated90 ? rawW : rawH;

        if (window.hasSelection) {
            const cx = window.cropRect.x;
            const cy = window.cropRect.y;
            const cw = window.cropRect.width;
            const ch = window.cropRect.height;
            if (isVertical) {
                window.cropRect = Qt.rect(cx, uncroppedH - (cy + ch), cw, ch);
            } else {
                window.cropRect = Qt.rect(uncroppedW - (cx + cw), cy, cw, ch);
            }
        }

        const list = [...window.strokes];
        for (let s of list) {
            if (s.points) {
                s.points = s.points.map(p => ({
                    x: isVertical ? p.x : uncroppedW - p.x,
                    y: isVertical ? uncroppedH - p.y : p.y
                }));
            }
        }
        window.strokes = list;

        if (window.bgRotation === 0 || window.bgRotation === 180) {
            if (isVertical) window.bgFlipV = !window.bgFlipV;
            else window.bgFlipH = !window.bgFlipH;
        } else {
            if (isVertical) window.bgFlipH = !window.bgFlipH;
            else window.bgFlipV = !window.bgFlipV;
        }

        window.requestPaintAll();
    }

    function resetRegionScanRect() {
        window.ocrRect = Qt.rect(0, 0, 0, 0);
    }

    function startRegionScanTool(tool) {
        window.resetRegionScanRect();
        window.currentTool = tool;
        window.requestActiveCanvasPaint();
    }

    function finishRegionScanTool() {
        window.currentTool = window.lastActiveTool;
        window.resetRegionScanRect();
        window.requestActiveCanvasPaint();
    }

    function getRegionScanCrop() {
        const r = window.ocrRect;
        if (r.width < 10 || r.height < 10) return null;

        // Account for crop offset when mapping to source image coordinates.
        const cropOffsetX = window.hasSelection ? window.cropRect.x : 0;
        const cropOffsetY = window.hasSelection ? window.cropRect.y : 0;
        return {
            x: Math.round(r.x + cropOffsetX),
            y: Math.round(r.y + cropOffsetY),
            width: Math.round(r.width),
            height: Math.round(r.height)
        };
    }

    function getBackgroundImagePath() {
        let bgPath = decodeURIComponent(window.bgImageSource.toString());
        if (bgPath.startsWith("file://")) bgPath = bgPath.substring(7);
        const qIdx = bgPath.indexOf("?");
        if (qIdx !== -1) bgPath = bgPath.substring(0, qIdx);
        return bgPath;
    }

    function makeTempCropPath(kind) {
        const uniqueId = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
        return `/tmp/dms_${kind}_crop_${uniqueId}.png`;
    }

    function runOcr() {
        window.startRegionScanTool("ocr");
    }

    function executeOcr() {
        const crop = window.getRegionScanCrop();
        if (!crop) {
            window.resetRegionScanRect();
            window.requestActiveCanvasPaint();
            return;
        }

        const bgPath = window.getBackgroundImagePath();
        let ocrLang = "eng";

        const tempCropPath = window.makeTempCropPath("ocr");
        Proc.runCommand("crop-ocr-temp", ["magick", bgPath, "-crop", `${crop.width}x${crop.height}+${crop.x}+${crop.y}`, tempCropPath], (stdout1, exitCode1) => {
            if (exitCode1 === 0) {
                Proc.runCommand("run-ocr", ["tesseract", tempCropPath, "-", "-l", ocrLang], (stdout2, exitCode2) => {
                    Proc.runCommand("cleanup-ocr-temp", ["rm", "-f", tempCropPath]);

                    if (exitCode2 === 0) {
                        const result = stdout2.trim();
                        if (result) {
                            DMSService.sendRequest("clipboard.copy", { "text": result }, function(response) {
                                if (typeof ToastService !== "undefined" && ToastService) {
                                    ToastService.showInfo(I18n.tr("OCR: %1 chars copied to clipboard").arg(result.length));
                                }
                            });
                        } else {
                            if (typeof ToastService !== "undefined" && ToastService) {
                                ToastService.showInfo(I18n.tr("OCR: No text detected"));
                            }
                        }
                    } else {
                        if (typeof ToastService !== "undefined" && ToastService) {
                            ToastService.showError(I18n.tr("OCR failed during text extraction"));
                        }
                    }
                    window.finishRegionScanTool();
                });
            } else {
                if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError(I18n.tr("OCR failed: Could not crop image"));
                }
                window.finishRegionScanTool();
            }
        });
    }

    function runQrScan() {
        window.startRegionScanTool("qr");
    }

    function executeQrScan() {
        const crop = window.getRegionScanCrop();
        if (!crop) {
            window.resetRegionScanRect();
            window.requestActiveCanvasPaint();
            return;
        }

        const bgPath = window.getBackgroundImagePath();

        const tempCropPath = window.makeTempCropPath("qr");
        Proc.runCommand("crop-qr-temp", ["magick", bgPath, "-crop", `${crop.width}x${crop.height}+${crop.x}+${crop.y}`, tempCropPath], (stdout1, exitCode1) => {
            if (exitCode1 === 0) {
                Proc.runCommand("run-qr-scan", ["zbarimg", "--raw", "-q", tempCropPath], (stdout2, exitCode2) => {
                    Proc.runCommand("cleanup-qr-temp", ["rm", "-f", tempCropPath]);

                    if (exitCode2 === 0) {
                        const result = stdout2.trim();
                        if (result) {
                            DMSService.sendRequest("clipboard.copy", { "text": result }, function(response) {
                                if (typeof ToastService !== "undefined" && ToastService) {
                                    ToastService.showInfo(I18n.tr("QR Decoded: Copied to clipboard"));
                                }
                            });
                        } else {
                            if (typeof ToastService !== "undefined" && ToastService) {
                                ToastService.showInfo(I18n.tr("QR Scan: No QR code detected"));
                            }
                        }
                    } else if (exitCode2 === 4) {
                        if (typeof ToastService !== "undefined" && ToastService) {
                            ToastService.showInfo(I18n.tr("QR Scan: No QR code detected"));
                        }
                    } else {
                        if (typeof ToastService !== "undefined" && ToastService) {
                            ToastService.showError(I18n.tr("QR Scan failed or command execution error"));
                        }
                    }
                    window.finishRegionScanTool();
                });
            } else {
                if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError(I18n.tr("QR Scan failed: Could not crop image"));
                }
                window.finishRegionScanTool();
            }
        });
    }

    shouldBeVisible: false
    
    // Modal sized to the screenshot (logical px), clamped between the toolbar's
    // footprint and 90% of the screen; falls back to 90% until the image loads
    readonly property real _screenW: window.targetScreen ? window.targetScreen.width : (Quickshell.screens[0] ? Quickshell.screens[0].width : 1920)
    readonly property real _screenH: window.targetScreen ? window.targetScreen.height : (Quickshell.screens[0] ? Quickshell.screens[0].height : 1080)
    readonly property real _maxModalW: Math.round((config.modalAspectRatio === "portrait" ? Math.min(_screenW, _screenH) : Math.max(_screenW, _screenH)) * 0.9)
    readonly property real _maxModalH: Math.round((config.modalAspectRatio === "portrait" ? Math.max(_screenW, _screenH) : Math.min(_screenW, _screenH)) * 0.9)
    readonly property bool _toolbarHorizontal: window.toolbarPosition === "top" || window.toolbarPosition === "bottom"
    // Chrome = boardContainer margins plus the edge the toolbar occupies (56px rail + its margin)
    readonly property real _chromeW: Theme.spacingM * 2 + (window.toolbarVisible && !_toolbarHorizontal ? 56 + Theme.spacingM : 0)
    readonly property real _chromeH: Theme.spacingM * 2 + (window.toolbarVisible && _toolbarHorizontal ? 56 + Theme.spacingM : 0)
    readonly property real _minModalW: _toolbarHorizontal && window.toolbarItem && window.toolbarItem.width ? window.toolbarItem.width + Theme.spacingM * 2 : 400
    readonly property real _minModalH: !_toolbarHorizontal && window.toolbarItem && window.toolbarItem.height ? window.toolbarItem.height + Theme.spacingM * 2 : 300
    readonly property bool _bgSizeKnown: window.bgImageItem
                                         && window.bgImageItem.status === Image.Ready
                                         && window.bgImageItem.sourceSize.width > 0
                                         && window.bgImageItem.sourceSize.height > 0
    // Compositor scale (not Screen.devicePixelRatio, which reports the integer buffer scale)
    readonly property real _outputScale: (window.targetScreen && CompositorService.getScreenScale(window.targetScreen)) || 1
    readonly property bool _shouldScale: !!(window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.modalScaleToContent)
    modalWidth: _shouldScale && _bgSizeKnown ? Math.round(Math.min(_maxModalW, Math.max(_minModalW, window.bgImageItem.sourceSize.width / _outputScale + _chromeW))) : _maxModalW
    modalHeight: _shouldScale && _bgSizeKnown ? Math.round(Math.min(_maxModalH, Math.max(_minModalH, window.bgImageItem.sourceSize.height / _outputScale + _chromeH))) : _maxModalH
    enableShadow: true
    positioning: "center"

    targetScreen: {
        const mode = config.modalDisplayTarget;
        const fallback = (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null;
        if (mode === "focused") {
            return CompositorService.getFocusedScreen() ?? fallback;
        }
        if (mode === "primary") {
            return fallback;
        }
        // Specific screen name matching with defensive check
        if (Quickshell.screens) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                const s = Quickshell.screens[i];
                if (s && s.name === mode) {
                    return s;
                }
            }
        }
        return (CompositorService.getFocusedScreen() ?? fallback);
    }

    // Component scope bridging properties
    property string bgImageSource: ""
    property int bgRotation: 0
    property bool bgFlipH: false
    property bool bgFlipV: false
    property var activeCanvas: null
    property var bakedCanvas: null
    property var bgImageItem: null
    property var boardContainerItem: null
    property var exportCanvasItem: null
    property var offscreenSamplerItem: null

    onSelectedStrokeChanged: window.requestPaintAll()
    onEffectiveBackdropModeChanged: window.requestPaintAll()
    onBackdropSolidColorChanged: window.requestPaintAll()
    onBackdropGradientStartChanged: window.requestPaintAll()
    onBackdropGradientEndChanged: window.requestPaintAll()
    onBackdropPaddingChanged: window.requestPaintAll()
    onBackdropCornerRadiusChanged: window.requestPaintAll()
    onBackdropShadowStrengthChanged: window.requestPaintAll()
    onBackdropGradientAngleChanged: window.requestPaintAll()
    onBackdropAspectRatioChanged: window.requestPaintAll()
    onEditScaleChanged: window.requestPaintAll()

    function requestPaintAll() {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
        if (window.bakedCanvas) window.bakedCanvas.requestPaint();
    }

    function applyEditorAnnotationTransform(ctx, isBackdropActive) {
        if (isBackdropActive || window.hasActiveCropSelection) {
            const cropX = window.hasActiveCropSelection ? window.cropRect.x : 0;
            const cropY = window.hasActiveCropSelection ? window.cropRect.y : 0;
            ctx.translate(window.screenshotXOffset, window.screenshotYOffset);
            if (isBackdropActive) {
                ctx.scale(window.backdropScaleFactor, window.backdropScaleFactor);
            }
            ctx.translate(-cropX, -cropY);
        } else if (window.hasSelection) {
            ctx.beginPath();
            ctx.rect(window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height);
            ctx.clip();
        }
    }

    function applyExportAnnotationTransform(ctx, isBackdropActive) {
        if (isBackdropActive || window.hasActiveCropSelection) {
            const cropX = window.hasActiveCropSelection ? window.cropRect.x : 0;
            const cropY = window.hasActiveCropSelection ? window.cropRect.y : 0;
            ctx.translate(window.screenshotXOffset, window.screenshotYOffset);
            ctx.scale(window.backdropScaleFactor, window.backdropScaleFactor);
            ctx.translate(-cropX, -cropY);
        }
    }

    function getSpotlightRenderConfig() {
        return {
            screenshotWidth: window.screenshotWidth,
            screenshotHeight: window.screenshotHeight,
            spotlightIntensity: window.spotlightIntensity,
            hasActiveCropSelection: window.hasActiveCropSelection,
            cropRect: window.cropRect,
            effectiveBackdropMode: window.effectiveBackdropMode,
            backdropCornerRadius: window.backdropCornerRadius,
            roundRect: window.roundRect,
            cornerRadius: Theme.cornerRadius
        };
    }

    function drawStroke(ctx, stroke) {
        DrawingRenderer.drawStroke(ctx, stroke, Helpers, Qt, Theme, {
            roundRect: window.roundRect,
            roundHighlighter: window.roundHighlighter,
            bgImageItem: window.bgImageItem,
            offscreenSampler: window.offscreenSamplerItem,
            canvasWidth: window.canvasWidth,
            canvasHeight: window.canvasHeight,
            canvasMinX: window.hasActiveCropSelection ? window.cropRect.x : 0,
            canvasMinY: window.hasActiveCropSelection ? window.cropRect.y : 0,
            stampFontFamily: window.stampFontFamily
        });
    }

    function drawBakedAnnotationLayer(ctx) {
        if (!window.showAnnotations) return;

        const strokes = window.strokes;
        const selectedStroke = window.selectedStroke;

        // Pixelate must render before spotlight dimming.
        for (let i = 0; i < strokes.length; i++) {
            if (strokes[i].tool === "pixelate" && strokes[i] !== selectedStroke) {
                window.drawStroke(ctx, strokes[i]);
            }
        }

        const isDrawingSpotlight = window.currentStroke && window.currentStroke.tool === "spotlight";
        const isEditingSpotlight = selectedStroke && selectedStroke.tool === "spotlight";
        const spotlightStrokes = strokes.filter(s => s.tool === "spotlight" && s !== selectedStroke);
        if (spotlightStrokes.length > 0 && !isDrawingSpotlight && !isEditingSpotlight) {
            DrawingRenderer.drawSpotlightOverlay(ctx, spotlightStrokes, window.getSpotlightRenderConfig());
        }

        for (let i = 0; i < strokes.length; i++) {
            if (strokes[i].tool !== "spotlight" && strokes[i].tool !== "pixelate" && strokes[i] !== selectedStroke && (!window.isTyping || strokes[i] !== window.editingStroke)) {
                window.drawStroke(ctx, strokes[i]);
            }
        }
    }

    function drawActiveAnnotationLayer(ctx) {
        if (!window.showAnnotations) return;

        const strokes = window.strokes;
        const selectedStroke = window.selectedStroke;

        if (window.currentStroke && window.currentStroke.tool === "pixelate") {
            const tempStroke = Object.assign({}, window.currentStroke, { isCurrent: true });
            window.drawStroke(ctx, tempStroke);
        }
        if (selectedStroke && selectedStroke.tool === "pixelate") {
            window.drawStroke(ctx, selectedStroke);
        }

        const isDrawingSpotlight = window.currentStroke && window.currentStroke.tool === "spotlight";
        const isEditingSpotlight = selectedStroke && selectedStroke.tool === "spotlight";
        if (isDrawingSpotlight || isEditingSpotlight) {
            const activeSpotlights = strokes.filter(s => s.tool === "spotlight" && s !== selectedStroke);
            if (isDrawingSpotlight) activeSpotlights.push(window.currentStroke);
            if (isEditingSpotlight) activeSpotlights.push(selectedStroke);

            DrawingRenderer.drawSpotlightOverlay(ctx, activeSpotlights, window.getSpotlightRenderConfig());

            if (window.currentStroke && (window.currentStroke.tool === "spotlight" || window.currentStroke.tool === "pixelate") && window.currentStroke.points.length >= 2) {
                const p0 = window.currentStroke.points[0];
                const p1 = window.currentStroke.points[window.currentStroke.points.length - 1];
                const rx = Math.min(p0.x, p1.x);
                const ry = Math.min(p0.y, p1.y);
                const rw = Math.abs(p1.x - p0.x);
                const rh = Math.abs(p1.y - p0.y);
                DrawingRenderer.drawHighContrastDashedRect(ctx, rx, ry, rw, rh);
            }
        }

        if (window.currentStroke && window.currentStroke.tool !== "spotlight" && window.currentStroke.tool !== "pixelate") {
            const tempStroke = Object.assign({}, window.currentStroke, { isCurrent: true });
            window.drawStroke(ctx, tempStroke);
        }

        if (selectedStroke && selectedStroke.tool !== "spotlight" && selectedStroke.tool !== "pixelate" && (!window.isTyping || selectedStroke !== window.editingStroke)) {
            window.drawStroke(ctx, selectedStroke);
        }

        let pastePreview = null;
        if (window.pastePreviewActive) {
            pastePreview = window.getPastePreviewStroke();
            if (pastePreview) window.drawStroke(ctx, pastePreview);
        }

        const handleStroke = pastePreview || selectedStroke;
        if (handleStroke && window.currentTool === "select") {
            DrawingRenderer.drawSelectionHandles(ctx, handleStroke, Theme, window.estimateTextWidth, Qt, Helpers);
        }
    }

    function drawTypingPreview(ctx) {
        if (!window.isTyping) return;

        ctx.fillStyle = window.currentColor;

        let styleStr = "";
        if (window.textItalic) styleStr += "italic ";
        if (window.textBold) styleStr += "bold ";

        ctx.font = `${styleStr}${Math.round(window.textFontSize)}px ${window.textFontFamily}`;
        ctx.textAlign = "left";
        ctx.textBaseline = "middle";

        const rawText = window.currentTypingText || "";
        const previewLines = rawText.split("\n");
        const lineH = window.textFontSize * 1.35;

        if (window.textBackground) {
            let maxW = 0;
            for (let li = 0; li < previewLines.length; li++) {
                const m = ctx.measureText(previewLines[li]);
                if (m.width > maxW) maxW = m.width;
            }
            if (maxW === 0) maxW = Math.max(10, window.textFontSize * 0.4);
            const h = window.textFontSize;
            const padX = h * 0.3;
            const padY = h * 0.15;
            const totalH = previewLines.length * lineH - (lineH - h);
            const rx = window.typingCoords.x - padX;
            const ry = window.typingCoords.y - padY;
            const rw = maxW + padX * 2;
            const rh = totalH + padY * 2;
            const radius = window.textCornerRadius;

            ctx.fillStyle = Helpers.getContrastingColor(window.currentColor.toString(), Qt);

            if (radius > 0) {
                ctx.beginPath();
                ctx.moveTo(rx + radius, ry);
                ctx.lineTo(rx + rw - radius, ry);
                ctx.quadraticCurveTo(rx + rw, ry, rx + rw, ry + radius);
                ctx.lineTo(rx + rw, ry + rh - radius);
                ctx.quadraticCurveTo(rx + rw, ry + rh, rx + rw - radius, ry + rh);
                ctx.lineTo(rx + radius, ry + rh);
                ctx.quadraticCurveTo(rx, ry + rh, rx, ry + rh - radius);
                ctx.lineTo(rx, ry + radius);
                ctx.quadraticCurveTo(rx, ry, rx + radius, ry);
                ctx.closePath();
                ctx.fill();
            } else {
                ctx.fillRect(rx, ry, rw, rh);
            }

            ctx.fillStyle = window.currentColor;
        }

        for (let li = 0; li < previewLines.length; li++) {
            ctx.fillText(previewLines[li], window.typingCoords.x, window.typingCoords.y + li * lineH + window.textFontSize / 2);
        }

        if (window.textUnderline) {
            ctx.strokeStyle = window.currentColor;
            ctx.lineWidth = Math.max(1.5, Math.round(window.textFontSize * 0.08));
            for (let li = 0; li < previewLines.length; li++) {
                const textWidth = ctx.measureText(previewLines[li]).width;
                ctx.beginPath();
                ctx.moveTo(window.typingCoords.x, window.typingCoords.y + li * lineH + window.textFontSize * 1.05);
                ctx.lineTo(window.typingCoords.x + textWidth, window.typingCoords.y + li * lineH + window.textFontSize * 1.05);
                ctx.stroke();
            }
        }

        if (window.typingCursorVisible) {
            let cursorLine = 0;
            let charAcc = 0;
            let cursorCol = 0;
            const targetIdx = Math.max(0, Math.min(rawText.length, window.typingCursorIndex));

            for (let i = 0; i < previewLines.length; i++) {
                const lineLen = previewLines[i].length;
                if (targetIdx <= charAcc + lineLen) {
                    cursorLine = i;
                    cursorCol = targetIdx - charAcc;
                    break;
                }
                charAcc += lineLen + 1;
            }

            const subText = (previewLines[cursorLine] || "").substring(0, cursorCol);
            const subW = ctx.measureText(subText).width;
            const curX = window.typingCoords.x + subW;
            const curY = window.typingCoords.y + cursorLine * lineH;

            ctx.strokeStyle = window.currentColor;
            ctx.lineWidth = Math.max(2, Math.round(window.textFontSize * 0.07));
            ctx.beginPath();
            ctx.moveTo(curX, curY);
            ctx.lineTo(curX, curY + window.textFontSize);
            ctx.stroke();
        }
    }

    function drawExportAnnotationLayer(ctx, isBackdropActive) {
        if (!window.showAnnotations) return;

        ctx.save();
        window.applyExportAnnotationTransform(ctx, isBackdropActive);

        for (let i = 0; i < window.strokes.length; i++) {
            if (window.strokes[i].tool === "pixelate") {
                window.drawStroke(ctx, window.strokes[i]);
            }
        }
        if (window.currentStroke && window.currentStroke.tool === "pixelate") {
            window.drawStroke(ctx, window.currentStroke);
        }

        const isDrawingSpotlight = window.currentStroke && window.currentStroke.tool === "spotlight";
        if (window.hasSpotlights || isDrawingSpotlight) {
            const spotlights = window.strokes.filter(s => s.tool === "spotlight");
            if (isDrawingSpotlight) {
                spotlights.push(window.currentStroke);
            }

            if (spotlights.length > 0) {
                DrawingRenderer.drawSpotlightOverlay(ctx, spotlights, window.getSpotlightRenderConfig());
            }
        }

        for (let i = 0; i < window.strokes.length; i++) {
            if (window.strokes[i].tool !== "pixelate" && window.strokes[i].tool !== "spotlight") {
                window.drawStroke(ctx, window.strokes[i]);
            }
        }

        if (window.currentStroke && window.currentStroke.tool !== "pixelate" && window.currentStroke.tool !== "spotlight") {
            window.drawStroke(ctx, window.currentStroke);
        }

        ctx.restore();
    }

    function getWatermarkRenderConfig(enabled) {
        const pData = (window.parentWidget && window.parentWidget.pluginData) || {};
        return {
            enabled: enabled && pData.enableWatermark,
            type: pData.watermarkType || "text",
            opacity: (pData.watermarkOpacity !== undefined ? pData.watermarkOpacity : 20) / 100.0,
            position: pData.watermarkPosition || "bottom_right",
            text: pData.watermarkText || "© {user}",
            textScale: (pData.watermarkTextSize !== undefined ? pData.watermarkTextSize : 5) / 100.0,
            imageScale: (pData.watermarkSize !== undefined ? pData.watermarkSize : 5) / 100.0,
            canvasWidth: window.canvasWidth,
            canvasHeight: window.canvasHeight,
            imageLoader: watermarkImageLoader,
            imageReady: watermarkImageLoader.status === Image.Ready,
            imageSourceSize: watermarkImageLoader.sourceSize
        };
    }

    function drawWatermarkLayer(ctx, enabled) {
        DrawingRenderer.drawWatermark(ctx, window.getWatermarkRenderConfig(enabled), config);
    }

    function drawEditorBackgroundLayer(ctx, imgSource, isBackdropActive) {
        if (isBackdropActive) {
            window.drawBackdropBackground(ctx, window.canvasWidth, window.canvasHeight);
            window.drawScreenshotShadow(ctx, window.editScale);
            window.drawScreenshotImage(ctx, imgSource);
            return;
        }

        if (window.currentTool !== "colorpicker" || imgSource.status !== Image.Ready) return;

        if (window.hasSelection) {
            ctx.drawImage(imgSource, window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height, 0, 0, window.canvasWidth, window.canvasHeight);
        } else {
            ctx.drawImage(imgSource, 0, 0, window.canvasWidth, window.canvasHeight);
        }
    }

    function drawExportBackgroundLayer(ctx, imgSource, isBackdropActive) {
        if (isBackdropActive) {
            window.drawBackdropBackground(ctx, window.canvasWidth, window.canvasHeight);
            window.drawScreenshotShadow(ctx, 1 / window.dpr);
            window.drawScreenshotImage(ctx, imgSource);
            return;
        }

        if (imgSource.status !== Image.Ready) return;

        ctx.save();
        const rawW = imgSource.sourceSize.width;
        const rawH = imgSource.sourceSize.height;
        const isRotated90 = (window.bgRotation === 90 || window.bgRotation === 270);
        const uncroppedW = isRotated90 ? rawH : rawW;
        const uncroppedH = isRotated90 ? rawW : rawH;

        if (window.hasSelection) {
            ctx.translate(-window.cropRect.x, -window.cropRect.y);
        }

        ctx.translate(uncroppedW / 2, uncroppedH / 2);
        if (window.bgRotation !== 0) {
            ctx.rotate(window.bgRotation * Math.PI / 180);
        }
        const sx = window.bgFlipH ? -1 : 1;
        const sy = window.bgFlipV ? -1 : 1;
        if (sx !== 1 || sy !== 1) {
            ctx.scale(sx, sy);
        }

        ctx.drawImage(imgSource, -rawW / 2, -rawH / 2, rawW, rawH);
        ctx.restore();
    }

    function renderBakedCanvas(canvas, imgSource) {
        const ctx = canvas.getContext("2d");
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.save();
        ctx.scale(window.editScale, window.editScale);

        const isBackdropActive = window.effectiveBackdropMode !== "none";
        window.drawEditorBackgroundLayer(ctx, imgSource, isBackdropActive);

        ctx.save();
        window.applyEditorAnnotationTransform(ctx, isBackdropActive);
        window.drawBakedAnnotationLayer(ctx);
        ctx.restore();

        window.drawWatermarkLayer(ctx, window.currentTool !== "crop");

        ctx.restore();
    }

    function finishExportCanvas(canvas) {
        const tempOut = `/tmp/dms_capture_${Date.now()}.png`;
        canvas.save(tempOut);

        if (window.exportCallback) {
            const cb = window.exportCallback;
            window.exportCallback = null;
            Qt.callLater(() => {
                cb(tempOut);
            });
        }
    }

    function renderExportCanvas(canvas, imgSource) {
        const ctx = canvas.getContext("2d");
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.save();
        ctx.scale(1 / window.dpr, 1 / window.dpr);

        const isBackdropActive = window.effectiveBackdropMode !== "none";
        window.drawExportBackgroundLayer(ctx, imgSource, isBackdropActive);
        window.drawExportAnnotationLayer(ctx, isBackdropActive);
        window.drawWatermarkLayer(ctx, true);

        ctx.restore();
        window.finishExportCanvas(canvas);
    }

    // Radial Menu Presets & History
    property var radialPresets: []
    property var presetHistory: []

    function recordPresetUsage(preset) {
        if (!preset) return;
        let history = [...window.presetHistory];
        
        // Find if preset (tool+color+thickness) is already in history and remove it
        const matchIdx = history.findIndex(p => 
            p.tool === preset.tool && 
            p.color.toString() === preset.color.toString() && 
            p.thickness === preset.thickness
        );
        if (matchIdx !== -1) history.splice(matchIdx, 1);
        
        // Add current to front
        history.unshift({
            tool: preset.tool,
            color: preset.color,
            thickness: preset.thickness
        });
        
        // Keep only latest 2 for toggling
        if (history.length > 2) history = history.slice(0, 2);
        window.presetHistory = history;
    }

    function getCursorAbsolutePoint() {
        const mx = window.cursorX;
        const my = window.cursorY;
        return window.hasActiveCropSelection ? Qt.point(mx + window.cropRect.x, my + window.cropRect.y) : Qt.point(mx, my);
    }

    function getPastePreviewStroke() {
        if (!window.copiedStroke) return;

        const absPt = window.getCursorAbsolutePoint();

        // Calculate the bounding box center of the copied stroke
        let minX = Infinity, maxX = -Infinity;
        let minY = Infinity, maxY = -Infinity;
        for (let i = 0; i < window.copiedStroke.points.length; i++) {
            const p = window.copiedStroke.points[i];
            if (p.x < minX) minX = p.x;
            if (p.x > maxX) maxX = p.x;
            if (p.y < minY) minY = p.y;
            if (p.y > maxY) maxY = p.y;
        }
        const centerX = (minX + maxX) / 2;
        const centerY = (minY + maxY) / 2;

        // Shift points so the pasted stroke is centered exactly at the current cursor position
        const dx = absPt.x - (isFinite(centerX) ? centerX : 0);
        const dy = absPt.y - (isFinite(centerY) ? centerY : 0);
        const newPoints = window.copiedStroke.points.map(p => Qt.point(p.x + dx, p.y + dy));
        
        const pasted = {
            tool: window.copiedStroke.tool,
            color: window.copiedStroke.color,
            width: window.copiedStroke.width,
            points: newPoints
        };
        Helpers.copyStrokeProperties(window.copiedStroke, pasted);
        return pasted;
    }

    function beginPastePreview() {
        if (!window.copiedStroke) return;
        window.pastePreviewActive = true;
        window.currentTool = "select";
        window.repaintActiveCanvas();
    }

    function cancelPastePreview() {
        if (!window.pastePreviewActive) return false;
        window.pastePreviewActive = false;
        window.repaintActiveCanvas();
        return true;
    }

    function performPasteAction() {
        const pasted = window.getPastePreviewStroke();
        if (!pasted) return;

        window.pushStroke(pasted);
        window.pastePreviewActive = false;

        if (window.currentTool === "select") {
            window.savePreGrabState();
            window.strokeWidth = pasted.width;
            window.currentColor = pasted.color;
            if (pasted.tool === "redact" && pasted.redactMode) window.activeRedactMode = pasted.redactMode;
            if (pasted.tool === "redact" && pasted.redactShape) window.activeRedactShape = pasted.redactShape;
            if (pasted.tool === "callout") window.calloutShape = pasted.calloutShape !== undefined ? pasted.calloutShape : "rect";
            window.selectedStroke = pasted;
            window.pressCoords = window.getCursorAbsolutePoint();
            window.originalPoints = window.copyStrokePoints(pasted.points);
        }

        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }

    function getPresetTool(index) {
        const val = window.pluginData[`preset_${index}_tool`];
        return val !== undefined ? val : (Constants.defaultRadialTools[index] || "none");
    }

    function getPresetColor(index) {
        const val = window.pluginData[`preset_${index}_color`];
        if (val !== undefined) return val;
        const defaultColors = ["primary", "primary", "primary", "primary", "primary", "primary", "#000000", "#ffffff"];
        return defaultColors[index] || "primary";
    }

    function getPresetThickness(index) {
        const val = window.pluginData[`preset_${index}_thickness`];
        if (val === undefined) return Constants.getToolMeta("pen").defaultValue;
        const parsed = parseInt(val, 10);
        return isNaN(parsed) ? Constants.getToolMeta("pen").defaultValue : parsed;
    }

    function updateRadialPresets() {
        const list = [];
        for (let i = 0; i < 8; i++) {
            const t = window.getPresetTool(i);
            if (t && t !== "none") {
                const rawColor = window.getPresetColor(i);
                const resolvedColor = config.resolveColor(rawColor);
                list.push({
                    tool: t,
                    color: resolvedColor,
                    thickness: window.getPresetThickness(i)
                });
            }
        }
        window.radialPresets = list;
    }

    // Dynamic scale to fit the screenshot (supports standard, high-DPI, and multi-monitor setups)
    property real fitScale: {
        if (!activeCanvas || !bgImageItem || !boardContainerItem) return 1.0;
        const maxW = boardContainerItem.width;
        const maxH = boardContainerItem.height;
        const targetW = window.canvasWidth;
        const targetH = window.canvasHeight;
        if (targetW <= 0 || targetH <= 0) return 1.0;
        const scaleX = maxW / targetW;
        const scaleY = maxH / targetH;
        const scale = Math.min(scaleX, scaleY);
        if (window.hasActiveCropSelection) {
            return Math.min(scale, 1.0);
        }
        return scale;
    }

    // Crop Selection State
    property rect cropRect: Qt.rect(0, 0, 0, 0)
    property bool hasSelection: false
    readonly property bool roundRect: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.roundRect !== undefined ? window.parentWidget.pluginData.roundRect : true
    readonly property bool roundHighlighter: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.roundHighlighter !== undefined ? window.parentWidget.pluginData.roundHighlighter : false
    readonly property bool penAutoClose: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.penAutoClose !== undefined ? window.parentWidget.pluginData.penAutoClose : false

    property string activeHandle: "none" // "tl", "tr", "bl", "br", "new", "none"
    property point selectStart: Qt.point(0, 0)
    property rect ocrRect: Qt.rect(0, 0, 0, 0)
    property var exportCallback: null

    property var restoreState: null
    property string restoreSource: ""
    property string currentCapturePath: ""
    property var floatService: null

    Connections {
        target: window.floatService
        function onRestoreRequested(imageSource, annotationState) {
            window.restoreSource = imageSource;
            window.restoreState = annotationState;
            window.shouldBeVisible = true;
            window.open();
        }
    }

    QuickCaptureActions {
        id: captureActions
        parentWidget: window.parentWidget
        modal: window
        exportAndExecute: window.exportAndExecute
        floatService: window.floatService
        onCloseRequested: window.discardAndClose()
    }

    function getHoveredHandle(mx, my) {
        if (!hasSelection || currentTool !== "crop") return "none";
        const threshold = 15;
        const x1 = cropRect.x;
        const y1 = cropRect.y;
        const x2 = cropRect.x + cropRect.width;
        const y2 = cropRect.y + cropRect.height;

        // Check corners first
        if (Math.abs(mx - x1) <= threshold && Math.abs(my - y1) <= threshold) return "tl";
        if (Math.abs(mx - x2) <= threshold && Math.abs(my - y1) <= threshold) return "tr";
        if (Math.abs(mx - x1) <= threshold && Math.abs(my - y2) <= threshold) return "bl";
        if (Math.abs(mx - x2) <= threshold && Math.abs(my - y2) <= threshold) return "br";

        // Check full edges
        if (Math.abs(my - y1) <= threshold && mx >= x1 && mx <= x2) return "tc";
        if (Math.abs(my - y2) <= threshold && mx >= x1 && mx <= x2) return "bc";
        if (Math.abs(mx - x1) <= threshold && my >= y1 && my <= y2) return "lc";
        if (Math.abs(mx - x2) <= threshold && my >= y1 && my <= y2) return "rc";

        return "none";
    }

    function clampCropRect(x, y, w, h) {
        const bw = window.screenshotWidth;
        const bh = window.screenshotHeight;
        const minSize = 10;
        const cx = Math.max(0, Math.min(x, Math.max(0, bw - minSize)));
        const cy = Math.max(0, Math.min(y, Math.max(0, bh - minSize)));
        const cw = Math.max(minSize, Math.min(w, bw - cx));
        const ch = Math.max(minSize, Math.min(h, bh - cy));
        return Qt.rect(cx, cy, cw, ch);
    }

    function backdropConfigValue(key, defaultValue, numeric) {
        const pd = config && config.pluginData;
        if (!pd || pd[key] === undefined || pd[key] === null) return defaultValue;
        return numeric ? parseInt(pd[key], 10) : pd[key];
    }

    function backdropConfigColor(key, defaultValue) {
        const pd = config && config.pluginData;
        if (!pd) return defaultValue;
        const val = pd[key];
        if (!val) return defaultValue;
        return config.resolveColor(val);
    }

    function estimateTextWidth(text, fontSize, isBold, isMonospace) {
        return Helpers.estimateTextWidth(text, fontSize, isBold, isMonospace);
    }

    function findStrokeAt(mx, my) {
        return Helpers.findStrokeAt(mx, my, window.strokes, window.estimateTextWidth);
    }

    function getSelectedStrokeHandleAt(mx, my) {
        if (!window.selectedStroke) return "none";
        return Helpers.getStrokeHandleAt(mx, my, window.selectedStroke, window.estimateTextWidth);
    }

    function exportAndExecute(callback) {
        if (window.isTyping) {
            window.commitTypingText();
        }
        window.exportCallback = callback;
        if (!window.exportCanvasItem) {
            console.warn("exportCanvasItem is not initialized yet");
            return;
        }
        if (window.hasSelection && window.effectiveBackdropMode === "none") {
            window.exportCanvasItem.width = window.cropRect.width / window.dpr;
            window.exportCanvasItem.height = window.cropRect.height / window.dpr;
        } else if (window.activeCanvas) {
            window.exportCanvasItem.width = window.canvasWidth / window.dpr;
            window.exportCanvasItem.height = window.canvasHeight / window.dpr;
        }
        window.exportCanvasItem.requestPaint();
    }

    function formatHexColor(color) { return Helpers.formatHexColor(color); }

    function reindexStamps() {
        let stamps = [];
        for (let i = 0; i < window.strokes.length; i++) {
            let stroke = window.strokes[i];
            if (stroke && stroke.tool === "stamp") {
                if (stroke.id === undefined) {
                    stroke.id = window.stampIdCounter++;
                }
                stamps.push(stroke);
            }
        }

        stamps.sort((a, b) => a.id - b.id);

        let modified = false;
        for (let i = 0; i < stamps.length; i++) {
            let stroke = stamps[i];
            let stampCount = i + 1;
            if (stroke.counter !== stampCount) {
                stroke.counter = stampCount;
                modified = true;
            }
            if (stroke.format !== window.stampCounterFormat) {
                stroke.format = window.stampCounterFormat;
                modified = true;
            }
        }

        const nextCounter = stamps.length + 1;
        if (window.stampCounter !== nextCounter) {
            window.stampCounter = nextCounter;
        }
        if (modified && window.activeCanvas) {
            window.activeCanvas.requestPaint();
        }
    }

    function updateColorSlot(slotIdx, colorValue) {
        const hex = window.formatHexColor(colorValue).toUpperCase();
        if (config.selectedPreset !== "custom") {
            window.pendingColorToSave = colorValue;
            window.pendingSlotToSave = slotIdx;
            if (window.paletteWarningDialogRef) window.paletteWarningDialogRef.open();
        } else {
            window.currentColor = colorValue;
            window.writeColorSlotToCustom(slotIdx, hex);
        }
    }

    function openColorPickerModal() {
        if (typeof PopoutService !== "undefined" && PopoutService && PopoutService.colorPickerModal) {
            PopoutService.colorPickerModal.selectedColor = window.currentColor;
            PopoutService.colorPickerModal.pickerTitle = I18n.tr("Choose Color");
            PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                window.updateColorSlot(window.activeColorSlotIndex, selectedColor);
            };
            PopoutService.colorPickerModal.show();
            return true;
        }
        return false;
    }

    function writeColorSlotToCustom(slotIdx, hex) {
        if (!window.parentWidget || !window.parentWidget.pluginService || slotIdx < 0) return;
        
        let pData = Object.assign({}, window.parentWidget.pluginData);
        pData["color_palette_preset"] = "custom";
        
        const key = slotIdx === 0 ? "toolbar_color_primary" : "toolbar_color_" + (slotIdx - 1);
        pData[key] = hex;
        
        window.parentWidget.pluginData = pData;
        
        window.parentWidget.pluginService.savePluginData("quickCapture", "color_palette_preset", "custom");
        window.parentWidget.pluginService.savePluginData("quickCapture", key, hex);
    }

    function switchPresetToCustom(copyCurrent) {
        if (!window.parentWidget || !window.parentWidget.pluginService) return;
        
        // 1. Read current palette FIRST before switching preset to custom
        // to avoid QML reactive bindings immediately resetting the palette to custom empty/defaults.
        const currentPalette = (copyCurrent && window.toolbarItem && window.toolbarItem.toolbarPalette) ? window.toolbarItem.toolbarPalette : [];
        
        let pData = Object.assign({}, window.parentWidget.pluginData);
        pData["color_palette_preset"] = "custom";
        window.parentWidget.pluginService.savePluginData("quickCapture", "color_palette_preset", "custom");
        
        if (copyCurrent && currentPalette && currentPalette.length >= 8) {
            pData["toolbar_color_primary"] = window.formatHexColor(currentPalette[0]).toUpperCase();
            window.parentWidget.pluginService.savePluginData("quickCapture", "toolbar_color_primary", pData["toolbar_color_primary"]);
            
            for (let i = 0; i < 7; i++) {
                const key = `toolbar_color_${i}`;
                pData[key] = window.formatHexColor(currentPalette[i + 1]).toUpperCase();
                window.parentWidget.pluginService.savePluginData("quickCapture", key, pData[key]);
            }
        }
        
        if (window.pendingSlotToSave >= 0) {
            const hex = window.formatHexColor(window.pendingColorToSave).toUpperCase();
            const key = window.pendingSlotToSave === 0 ? "toolbar_color_primary" : "toolbar_color_" + (window.pendingSlotToSave - 1);
            pData[key] = hex;
            window.parentWidget.pluginService.savePluginData("quickCapture", key, hex);
            
            window.parentWidget.pluginData = pData;
            window.currentColor = window.pendingColorToSave;
        }
        
        window.pendingColorToSave = "transparent";
        window.pendingSlotToSave = -1;
    }

    function sampleCanvasColor(mouseX, mouseY) {
        const canvas = window.bakedCanvas || window.activeCanvas;
        if (!canvas) return window.currentColor;
        
        // Clamp and round coordinates to prevent out-of-bounds errors and ensure integer coordinates in device pixels
        const x = Helpers.clamp(Math.floor(mouseX * window.dpr), 0, Math.floor(canvas.width * window.dpr) - 1);
        const y = Helpers.clamp(Math.floor(mouseY * window.dpr), 0, Math.floor(canvas.height * window.dpr) - 1);
        
        // Performance optimization: skip sampling if the pixel coordinates haven't changed
        if (window._lastSampledX === x && window._lastSampledY === y) {
            return window._lastSampledColor || window.currentColor;
        }
        
        try {
            const ctx = canvas.getContext("2d");
            if (!ctx) return window.currentColor;
            
            const imgData = ctx.getImageData(x, y, 1, 1);
            if (imgData && imgData.data && imgData.data.length >= 4) {
                const r = imgData.data[0];
                const g = imgData.data[1];
                const b = imgData.data[2];
                const a = imgData.data[3];
                
                let pickedColor;
                if (a === 0) {
                    pickedColor = window.currentColor;
                } else {
                    // Force alpha to 1.0 to ensure we always sample an opaque color.
                    pickedColor = Qt.rgba(r / 255, g / 255, b / 255, 1.0);
                }
                
                window._lastSampledX = x;
                window._lastSampledY = y;
                window._lastSampledColor = pickedColor;
                
                return pickedColor;
            }
        } catch (e) {
            console.warn("Color picker failed to sample pixel color:", e);
        }
        return window.currentColor;
    }

    function restartTypingCursor() {
        window.typingCursorVisible = true;
        typingCursorTimer.restart();
    }

    function clampedTypingCursorIndex() {
        const txt = window.currentTypingText || "";
        return Math.max(0, Math.min(txt.length, window.typingCursorIndex));
    }

    function setTypingText(text, cursorIndex) {
        window.currentTypingText = text;
        window.typingCursorIndex = Math.max(0, Math.min(text.length, cursorIndex));
        window.repaintActiveCanvas();
    }

    function insertTypingText(insertStr) {
        const txt = window.currentTypingText;
        const idx = window.clampedTypingCursorIndex();
        window.setTypingText(txt.slice(0, idx) + insertStr + txt.slice(idx), idx + insertStr.length);
    }

    function moveTypingCursor(delta) {
        const len = window.currentTypingText.length;
        window.typingCursorIndex = Math.max(0, Math.min(len, window.typingCursorIndex + delta));
        window.repaintActiveCanvas();
    }

    function deleteTypingTextBeforeCursor() {
        const txt = window.currentTypingText;
        const idx = window.clampedTypingCursorIndex();
        if (idx > 0) {
            window.setTypingText(txt.slice(0, idx - 1) + txt.slice(idx), idx - 1);
        }
    }

    function deleteTypingTextAfterCursor() {
        const txt = window.currentTypingText;
        const idx = window.clampedTypingCursorIndex();
        if (idx < txt.length) {
            window.setTypingText(txt.slice(0, idx) + txt.slice(idx + 1), idx);
        }
    }

    function cancelTypingText() {
        window.editingStroke = null;
        window.isTyping = false;
        window.currentTypingText = "";
        window.typingCursorIndex = 0;
        window.repaintActiveCanvas();
    }

    function handleTypingKey(event) {
        window.restartTypingCursor();

        if (event.key === Qt.Key_Escape) {
            window.cancelTypingText();
            return window.acceptKeyEvent(event);
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (event.modifiers & Qt.ShiftModifier) {
                window.insertTypingText("\n");
                return window.acceptKeyEvent(event);
            }
            window.commitTypingText();
            return window.acceptKeyEvent(event);
        }
        if (event.key === Qt.Key_Left) {
            window.moveTypingCursor(-1);
            return window.acceptKeyEvent(event);
        }
        if (event.key === Qt.Key_Right) {
            window.moveTypingCursor(1);
            return window.acceptKeyEvent(event);
        }
        if (event.key === Qt.Key_Home) {
            window.typingCursorIndex = 0;
            window.repaintActiveCanvas();
            return window.acceptKeyEvent(event);
        }
        if (event.key === Qt.Key_End) {
            window.typingCursorIndex = window.currentTypingText.length;
            window.repaintActiveCanvas();
            return window.acceptKeyEvent(event);
        }
        if (event.key === Qt.Key_Backspace) {
            window.deleteTypingTextBeforeCursor();
            return window.acceptKeyEvent(event);
        }
        if (event.key === Qt.Key_Delete) {
            window.deleteTypingTextAfterCursor();
            return window.acceptKeyEvent(event);
        }
        if (event.text && event.text.length > 0 && !(event.modifiers & Qt.ControlModifier) && !(event.modifiers & Qt.AltModifier)) {
            window.insertTypingText(event.text);
            window.acceptKeyEvent(event);
        }
    }

    function acceptKeyEvent(event) {
        event.accepted = true;
        return true;
    }

    function repaintActiveCanvas() {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }

    function handleSelectedStrokeDeleteShortcut(event) {
        if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && window.currentTool === "select" && window.selectedStroke) {
            const list = [...window.strokes];
            const idx = list.indexOf(window.selectedStroke);
            if (idx !== -1) {
                list.splice(idx, 1);
                window.undoneStrokes = [...window.undoneStrokes, window.selectedStroke];
                window.strokes = list;
            }
            window.deselectStrokeForEditing(false);
            window.repaintActiveCanvas();
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleSelectedStrokeMoveShortcut(event) {
        if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down)
            && window.currentTool === "select" && window.selectedStroke) {

            let step = (event.modifiers & Qt.ShiftModifier) ? 10 : 1;
            let dx = 0;
            let dy = 0;
            if (event.key === Qt.Key_Left) dx = -step;
            else if (event.key === Qt.Key_Right) dx = step;
            else if (event.key === Qt.Key_Up) dy = -step;
            else if (event.key === Qt.Key_Down) dy = step;

            const newPoints = [];
            for (let i = 0; i < window.selectedStroke.points.length; i++) {
                newPoints.push(Qt.point(window.selectedStroke.points[i].x + dx, window.selectedStroke.points[i].y + dy));
            }
            window.selectedStroke.points = newPoints;

            if (window.selectedStroke.tool === "redact") {
                window.selectedStroke.cachedCleanColor = undefined;
            }

            window.repaintActiveCanvas();
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleEscapeShortcut(event) {
        if (event.key === Qt.Key_Escape) {
            if (window.cancelPastePreview()) {
                return window.acceptKeyEvent(event);
            }
            if (window.currentStroke) {
                window.currentStroke = null;
                window.repaintActiveCanvas();
                return window.acceptKeyEvent(event);
            }
            if (window.currentTool === "select" && window.originalPoints && window.originalPoints.length > 0) {
                if (window.selectedStroke) {
                    window.selectedStroke.points = window.originalPoints.map(p => Qt.point(p.x, p.y));
                }
                window.activeHandle = "none";
                window.originalPoints = [];
                window.repaintActiveCanvas();
                return window.acceptKeyEvent(event);
            }
            if (window.selectedStroke) {
                window.deselectStrokeForEditing(false);
                window.repaintActiveCanvas();
                return window.acceptKeyEvent(event);
            }
            if (window.currentTool === "ocr" || window.currentTool === "qr") {
                window.currentTool = window.lastActiveTool;
                window.ocrRect = Qt.rect(0, 0, 0, 0);
                window.repaintActiveCanvas();
                return window.acceptKeyEvent(event);
            }
            if (window.currentTool === "crop" || window.hasSelection) {
                window.hasSelection = false;
                window.cropRect = Qt.rect(0, 0, 0, 0);
                window.activeHandle = "none";
                window.currentTool = window.lastActiveTool;
                window.requestPaintAll();
                return window.acceptKeyEvent(event);
            }
            window.discardAndClose();
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleCaptureActionShortcut(event, token, hasCtrl) {
        if (hasCtrl && (token === "Y" || (event.modifiers & Qt.ShiftModifier && token === "Z"))) {
            window.performRedo();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && token === "Z") {
            window.performUndo();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && (event.modifiers & Qt.ShiftModifier) && token === "C") {
            captureActions.performAnonymousCopy();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && token === "C") {
            captureActions.performCopyOnly();
            return window.acceptKeyEvent(event);
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            captureActions.performDoneAction();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && token === "S") {
            captureActions.performSaveOnly();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && token === "A") {
            captureActions.performCopyAndSave();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && token === "F") {
            captureActions.performFloatAction();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && token === "X") {
            window.currentTool = window.currentTool === "crop" ? window.lastActiveTool : "crop";
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleAnnotationVisibilityShortcut(event, token, hasCtrl) {
        if (token === "X" && !hasCtrl) {
            window.showAnnotations = !window.showAnnotations;
            window.repaintActiveCanvas();
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleStrokeClipboardShortcut(event, token, hasCtrl) {
        if (token === "C" && !hasCtrl) {
            if (window.currentTool !== "select" && window.strokes.length > 0) {
                window.currentTool = "select";
            }
            if (window.selectedStroke) {
                window.copiedStroke = {
                    tool: window.selectedStroke.tool,
                    color: window.selectedStroke.color.toString(),
                    width: window.selectedStroke.width,
                    points: window.selectedStroke.points.map(p => Qt.point(p.x, p.y))
                };
                Helpers.copyStrokeProperties(window.selectedStroke, window.copiedStroke);
                window.beginPastePreview();
                return window.acceptKeyEvent(event);
            } else if (window.copiedStroke) {
                window.beginPastePreview();
                return window.acceptKeyEvent(event);
            }
        }

        if (token === "V" && !hasCtrl) {
            window.currentTool = "select";
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleColorShortcut(event, token) {
        const colorShortcut = Helpers.findByKey(config.colorShortcuts, token);
        if (colorShortcut) {
            let idx = config.colorShortcuts.indexOf(colorShortcut);
            if (idx !== -1) {
                window.activeColorSlotIndex = idx;
            }
            window.currentColor = colorShortcut.color === "primary" ? Theme.primary : colorShortcut.color;
            event.accepted = true;
        }
    }

    function handleOcrShortcut(event, token, hasCtrl) {
        if (token === "O" && !hasCtrl) {
            if (window.currentTool === "ocr") {
                window.currentTool = window.lastActiveTool;
                window.ocrRect = Qt.rect(0, 0, 0, 0);
                window.repaintActiveCanvas();
            } else {
                window.runOcr();
            }
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleToolShortcut(event, token) {
        const toolShortcut = Helpers.findByKey(config.toolShortcuts, token);
        if (!toolShortcut) return false;

        if (toolShortcut.tool === "colorpicker") {
            if (!window.openColorPickerModal()) {
                if (window.currentTool === "colorpicker") {
                    window.currentTool = window.lastActiveTool;
                } else {
                    window.colorPickerMode = "draw";
                    window.currentTool = "colorpicker";
                }
            }
            return window.acceptKeyEvent(event);
        }

        if (window.currentTool === toolShortcut.tool) {
            if (toolShortcut.tool === "backdrop" || toolShortcut.tool === "crop") {
                window.currentTool = window.lastActiveTool;
            }
        } else {
            window.currentTool = toolShortcut.tool;
        }
        return window.acceptKeyEvent(event);
    }

    function handleShortcutKey(event) {
        if (window.handleSelectedStrokeDeleteShortcut(event)) return;
        if (window.handleSelectedStrokeMoveShortcut(event)) return;

        const token = Helpers.shortcutToken(event.key, Qt);
        const hasCtrl = event.modifiers & Qt.ControlModifier;

        if (window.handleEscapeShortcut(event)) return;
        if (window.handleCaptureActionShortcut(event, token, hasCtrl)) return;
        if (window.handleAnnotationVisibilityShortcut(event, token, hasCtrl)) return;
        if (window.handleStrokeClipboardShortcut(event, token, hasCtrl)) return;

        if (hasCtrl) {
            window.handleColorShortcut(event, token);
            return;
        }

        if (window.handleOcrShortcut(event, token, hasCtrl)) return;
        window.handleToolShortcut(event, token);
    }

    function handleTabShortcut(event) {
        if (event.key !== Qt.Key_Tab) return false;
        if (event.isAutoRepeat) {
            return window.acceptKeyEvent(event);
        }

        if (window.currentTool === "select") {
            window.currentTool = window.lastActiveTool;
        } else if (window.currentTool === window.lastActiveTool) {
            window.currentTool = "select";
        } else if (window.presetHistory.length >= 2) {
            const current = {
                tool: window.currentTool,
                color: window.currentColor.toString(),
                thickness: window.strokeWidth
            };
            const p0 = window.presetHistory[0];
            const p1 = window.presetHistory[1];

            const isP0 = current.tool === p0.tool &&
                         current.color.toString() === p0.color.toString() &&
                         current.thickness === p0.thickness;

            const target = isP0 ? p1 : p0;
            window.currentTool = target.tool;
            window.currentColor = target.color;
            window.strokeWidth = target.thickness;
            window.recordPresetUsage(target);
        } else {
            window.currentTool = "select";
        }

        return window.acceptKeyEvent(event);
    }

    function handleZoomKeyPressed(event) {
        if (event.key !== Qt.Key_G || window.isTyping) return false;
        if (event.isAutoRepeat) {
            return window.acceptKeyEvent(event);
        }
        window.isZoomPressed = true;
        return window.acceptKeyEvent(event);
    }

    function handleZoomKeyReleased(event) {
        if (event.key !== Qt.Key_G || window.isTyping) return false;
        if (event.isAutoRepeat) {
            return window.acceptKeyEvent(event);
        }
        window.isZoomPressed = false;
        return window.acceptKeyEvent(event);
    }

    function handleTypingKeyPressed(event) {
        if (!window.isTyping) return false;
        if (window.textInputMode === "inline") {
            window.handleTypingKey(event);
        } else if (event.key !== Qt.Key_Escape) {
            event.accepted = true;
        }
        return true;
    }

    function handleModalKeyPressed(event) {
        if (window.handleTabShortcut(event)) return;
        if (window.handleZoomKeyPressed(event)) return;
        if (window.handleTypingKeyPressed(event)) return;
        window.handleShortcutKey(event);
    }

    function handleModalKeyReleased(event) {
        if (event.key === Qt.Key_Tab) {
            event.accepted = true;
            return;
        }
        window.handleZoomKeyReleased(event);
    }

    onBackgroundClicked: () => discardAndClose()

    // Keyboard Shortcuts Support
    modalFocusScope.Keys.onPressed: (event) => {
        window.handleModalKeyPressed(event);
    }

    modalFocusScope.Keys.onReleased: (event) => {
        window.handleModalKeyReleased(event);
    }

    onOpened: {
        if (window.floatService) {
            window.floatService.hideAllWindows();
        }
        window.updateRadialPresets();

        let startTool = "pen";
        let startThickness = Constants.getToolMeta("pen").defaultValue;
        let startColor = Theme.primary;

        const defaultToolMode = config.pluginData.defaultToolMode || "preset";
        if (defaultToolMode === "preset") {
            const presetIdxRaw = config.pluginData.defaultPresetIndex || "0";
            const presetIdx = parseInt(presetIdxRaw, 10);
            const t = window.getPresetTool(presetIdx);
            if (t && t !== "none") {
                startTool = t;
                const rawColor = window.getPresetColor(presetIdx);
                startColor = config.resolveColor(rawColor);
                startThickness = window.getPresetThickness(presetIdx);
            } else {
                startTool = config.pluginData.defaultTool || "pen";
                startThickness = config.pluginData.defaultThickness || Constants.getToolMeta("pen").defaultValue;
            }
        } else {
            startTool = config.pluginData.defaultTool || "pen";
            startThickness = config.pluginData.defaultThickness || Constants.getToolMeta("pen").defaultValue;
        }

        window.currentTool = startTool;
        window.toolbarVisible = window.configShowToolbar;
        window.strokeWidth = startThickness;
        window.currentColor = startColor;
        window.recordPresetUsage({ tool: startTool, color: startColor, thickness: startThickness });

        window.strokes = [];
        window.showAnnotations = true;
        window.selectedStroke = null;
        window.copiedStroke = null;
        window.pastePreviewActive = false;
        window.stampCounter = 1;
        window.stampIdCounter = 1;
        window.bgRotation = 0;
        window.bgFlipH = false;
        window.bgFlipV = false;
        window.bgImageSource = "";
        if (window.restoreSource) {
            window.bgImageSource = window.restoreSource;
        } else if (window.currentCapturePath) {
            window.bgImageSource = `file://${window.currentCapturePath}`;
            // currentCapturePath is consumed in onDialogClosed to survive re-fires during screen changes
        }
        window.isScreenshotDark = false;
        window.hasSampledContrast = false;
        window.backdropSolidColor = backdropConfigColor("backdropDefaultSolidColor", config.resolveColor("slot_1"));
        window.backdropGradientStart = backdropConfigColor("backdropDefaultGradientStart", config.resolveColor("slot_1"));
        window.backdropGradientEnd = backdropConfigColor("backdropDefaultGradientEnd", config.resolveColor("slot_2"));

        const pd = config && config.pluginData;
        const hasCustomSolid = pd && pd["backdropDefaultSolidColor"] !== undefined;
        const hasCustomGradStart = pd && pd["backdropDefaultGradientStart"] !== undefined;
        const hasCustomGradEnd = pd && pd["backdropDefaultGradientEnd"] !== undefined;
        window.hasUserCustomizedBackdrop = !!(hasCustomSolid || hasCustomGradStart || hasCustomGradEnd);
        window.backdropMode = "none";
        if (config && config.pluginData && config.pluginData["backdropAutoApply"] === true) {
            const bm = config.pluginData["backdropDefaultMode"];
            if (bm) window.backdropMode = bm;
        }
        window.backdropPadding = backdropConfigValue("backdropDefaultPadding", Constants.defaultBackdropPadding, true);
        window.backdropCornerRadius = backdropConfigValue("backdropDefaultRadius", Constants.defaultBackdropCornerRadius, true);
        window.backdropShadowStrength = backdropConfigValue("backdropDefaultShadow", Constants.defaultBackdropShadowStrength, true);
        window.backdropGradientAngle = backdropConfigValue("backdropDefaultAngle", Constants.defaultBackdropGradientAngle, true);
        window.backdropAspectRatio = backdropConfigValue("backdropDefaultAspectRatio", Constants.defaultBackdropAspectRatio, false);
        window.backdropAlignment = backdropConfigValue("backdropDefaultAlignment", Constants.defaultBackdropAlignment, false);
        window.cropRect = Qt.rect(0, 0, 0, 0);
        window.hasSelection = false;
        window.activeHandle = "none";

        // Restore state from FloatService if returning from float window
        if (window.restoreState) {
            const data = window.restoreState;
            if (data.strokes) {
                const restoredStrokes = [];
                for (let rsi = 0; rsi < data.strokes.length; rsi++) {
                    const rs = data.strokes[rsi];
                    const stroke = {
                        tool: rs.tool,
                        color: rs.color,
                        width: rs.width,
                        points: rs.points ? rs.points.map(p => Qt.point(p.x, p.y)) : []
                    };
                    Helpers.copyStrokeProperties(rs, stroke);
                    restoredStrokes.push(stroke);
                }
                window.strokes = restoredStrokes;
            }
            if (data.originalBackground) {
                window.bgImageSource = data.originalBackground;
            }
            if (data.stampCounter !== undefined) {
                window.stampCounter = data.stampCounter;
            }
            if (data.bgRotation !== undefined) {
                window.bgRotation = data.bgRotation;
            }
            if (data.bgFlipH !== undefined) {
                window.bgFlipH = data.bgFlipH;
            }
            if (data.bgFlipV !== undefined) {
                window.bgFlipV = data.bgFlipV;
            }
            if (data.cropRect) {
                window.cropRect = Qt.rect(data.cropRect.x, data.cropRect.y, data.cropRect.width, data.cropRect.height);
                window.hasSelection = (data.cropRect.width > 0 && data.cropRect.height > 0);
            }
            if (data.backdropMode !== undefined) {
                window.backdropMode = data.backdropMode;
                window.backdropSolidColor = data.backdropSolidColor;
                window.backdropGradientStart = data.backdropGradientStart;
                window.backdropGradientEnd = data.backdropGradientEnd;
                window.backdropGradientAngle = data.backdropGradientAngle;
                window.backdropPadding = data.backdropPadding;
                window.backdropCornerRadius = data.backdropCornerRadius;
                window.backdropShadowStrength = data.backdropShadowStrength;
                window.backdropAspectRatio = data.backdropAspectRatio;
                window.customAspectRatio = data.customAspectRatio;
                if (data.backdropAlignment) window.backdropAlignment = data.backdropAlignment;
                window.hasUserCustomizedBackdrop = data.hasUserCustomizedBackdrop;
                window.autoBackdropGradientStart = data.autoBackdropGradientStart;
                window.autoBackdropGradientEnd = data.autoBackdropGradientEnd;
                window.autoBackdropSolidColor = data.autoBackdropSolidColor;
            }
            if (data.user_backdrop_presets) {
                try {
                    const parsed = JSON.parse(data.user_backdrop_presets);
                    if (Array.isArray(parsed)) window.customBackdropPresets = parsed;
                } catch (e) {
                    console.error("Failed to parse user_backdrop_presets:", e);
                }
            }
            if (data.hidden_backdrop_presets) {
                try {
                    const parsed = JSON.parse(data.hidden_backdrop_presets);
                    if (Array.isArray(parsed)) window.hiddenPresetIds = parsed;
                } catch (e) {
                    console.error("Failed to parse hidden_backdrop_presets:", e);
                }
            }
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            window.restoreState = null;
            window.restoreSource = "";
        }

        Qt.callLater(() => {
            if (modalFocusScope) modalFocusScope.forceActiveFocus();
        });
    }

    function applyBackdropPreset(preset) {
        if (!preset) return;
        if (preset.mode !== undefined) window.backdropMode = preset.mode;
        if (preset.solidColor !== undefined) window.backdropSolidColor = preset.solidColor;
        if (preset.gradientStart !== undefined) window.backdropGradientStart = preset.gradientStart;
        if (preset.gradientEnd !== undefined) window.backdropGradientEnd = preset.gradientEnd;
        if (preset.gradientAngle !== undefined) window.backdropGradientAngle = preset.gradientAngle;
        if (preset.padding !== undefined) window.backdropPadding = preset.padding;
        if (preset.cornerRadius !== undefined) window.backdropCornerRadius = preset.cornerRadius;
        if (preset.shadowStrength !== undefined) window.backdropShadowStrength = preset.shadowStrength;
        if (preset.aspectRatio !== undefined) window.backdropAspectRatio = preset.aspectRatio;
        if (preset.customAspectRatio !== undefined) window.customAspectRatio = preset.customAspectRatio;
        window.hasUserCustomizedBackdrop = true;
        window.requestPaintAll();
    }

    function saveCurrentBackdropAsPreset() {
        const idx = window.customBackdropPresets.length + 1;
        const newPreset = {
            id: `custom_${Date.now()}`,
            name: `Custom ${idx}`,
            mode: window.backdropMode,
            solidColor: window.backdropSolidColor.toString(),
            gradientStart: window.backdropGradientStart.toString(),
            gradientEnd: window.backdropGradientEnd.toString(),
            gradientAngle: window.backdropGradientAngle,
            padding: window.backdropPadding,
            cornerRadius: window.backdropCornerRadius,
            shadowStrength: window.backdropShadowStrength,
            aspectRatio: window.backdropAspectRatio,
            customAspectRatio: window.customAspectRatio,
            isCustomUserCreated: true
        };
        const newList = [...window.customBackdropPresets, newPreset];
        window.customBackdropPresets = newList;
        if (window.parentWidget && window.parentWidget.pluginService) {
            window.parentWidget.pluginService.savePluginData("quickCapture", "user_backdrop_presets", JSON.stringify(newList));
        }
    }

    function deletePreset(presetId) {
        if (!presetId) return;
        const newCustom = window.customBackdropPresets.filter(p => p.id !== presetId);
        const newHidden = window.hiddenPresetIds.indexOf(presetId) === -1 ? [...window.hiddenPresetIds, presetId] : window.hiddenPresetIds;
        window.customBackdropPresets = newCustom;
        window.hiddenPresetIds = newHidden;
        if (window.parentWidget && window.parentWidget.pluginService) {
            window.parentWidget.pluginService.savePluginData("quickCapture", "user_backdrop_presets", JSON.stringify(newCustom));
            window.parentWidget.pluginService.savePluginData("quickCapture", "hidden_backdrop_presets", JSON.stringify(newHidden));
        }
    }

    function updatePresetWithCurrent(presetId) {
        if (!presetId) return;
        const currentData = {
            mode: window.backdropMode,
            solidColor: window.backdropSolidColor.toString(),
            gradientStart: window.backdropGradientStart.toString(),
            gradientEnd: window.backdropGradientEnd.toString(),
            gradientAngle: window.backdropGradientAngle,
            padding: window.backdropPadding,
            cornerRadius: window.backdropCornerRadius,
            shadowStrength: window.backdropShadowStrength,
            aspectRatio: window.backdropAspectRatio,
            customAspectRatio: window.customAspectRatio
        };

        const existingIdx = window.customBackdropPresets.findIndex(p => p.id === presetId);
        let newList;
        if (existingIdx !== -1) {
            newList = window.customBackdropPresets.map(p => p.id === presetId ? Object.assign({}, p, currentData) : p);
        } else {
            const original = Constants.defaultBackdropPresets ? Constants.defaultBackdropPresets.find(p => p.id === presetId) : undefined;
            if (original) {
                const updated = Object.assign({}, original, currentData);
                newList = [...window.customBackdropPresets, updated];
            } else {
                newList = window.customBackdropPresets;
            }
        }
        window.customBackdropPresets = newList;
        if (window.parentWidget && window.parentWidget.pluginService) {
            window.parentWidget.pluginService.savePluginData("quickCapture", "user_backdrop_presets", JSON.stringify(newList));
        }
    }

    function renamePreset(presetId, newName) {
        if (!presetId || !newName) return;
        const existingIdx = window.customBackdropPresets.findIndex(p => p.id === presetId);
        let newList;
        if (existingIdx !== -1) {
            newList = window.customBackdropPresets.map(p => p.id === presetId ? Object.assign({}, p, { name: newName }) : p);
        } else {
            const original = Constants.defaultBackdropPresets ? Constants.defaultBackdropPresets.find(p => p.id === presetId) : undefined;
            if (original) {
                const updated = Object.assign({}, original, { name: newName });
                newList = [...window.customBackdropPresets, updated];
            } else {
                newList = window.customBackdropPresets;
            }
        }
        window.customBackdropPresets = newList;
        if (window.parentWidget && window.parentWidget.pluginService) {
            window.parentWidget.pluginService.savePluginData("quickCapture", "user_backdrop_presets", JSON.stringify(newList));
        }
    }

    function loadPresetsFromPluginData() {
        if (!config || !config.pluginData) return;
        
        const userPresetsRaw = config.pluginData["user_backdrop_presets"];
        if (userPresetsRaw !== undefined) {
            if (userPresetsRaw) {
                try {
                    const parsed = JSON.parse(userPresetsRaw);
                    if (Array.isArray(parsed)) {
                        window.customBackdropPresets = parsed;
                    }
                } catch (e) {
                    console.error("Failed to parse user_backdrop_presets:", e);
                }
            } else {
                window.customBackdropPresets = [];
            }
        }

        const hiddenPresetsRaw = config.pluginData["hidden_backdrop_presets"];
        if (hiddenPresetsRaw !== undefined) {
            if (hiddenPresetsRaw) {
                try {
                    const parsed = JSON.parse(hiddenPresetsRaw);
                    if (Array.isArray(parsed)) {
                        window.hiddenPresetIds = parsed;
                    }
                } catch (e) {
                    console.error("Failed to parse hidden_backdrop_presets:", e);
                }
            } else {
                window.hiddenPresetIds = [];
            }
        }
    }

    function focusModalAfterToolbarAction() {
        if (window.modalFocusScope) {
            window.modalFocusScope.forceActiveFocus();
        }
    }

    function closeMoreToolsMenu(menu) {
        if (menu) {
            menu.close();
        }
    }

    function handleToolbarToolSelected(tool, menu) {
        window.closeMoreToolsMenu(menu);
        if (tool === "back") {
            window.currentTool = window.lastActiveTool;
        } else if (tool === "crop" && window.currentTool === "crop") {
            window.currentTool = window.lastActiveTool;
        } else if (tool === "colorpicker-draw") {
            window.colorPickerMode = "draw";
            window.currentTool = "colorpicker";
        } else if (tool === "colorpicker-copy") {
            window.colorPickerMode = "copy";
            window.currentTool = "colorpicker";
        } else {
            window.currentTool = tool;
        }
        window.focusModalAfterToolbarAction();
    }

    function handleToolbarColorSelected(color, index, menu) {
        window.closeMoreToolsMenu(menu);
        window.activeColorSlotIndex = index;
        window.currentColor = color;
        window.focusModalAfterToolbarAction();
    }

    function handleToolbarCustomColorPickerRequested(menu) {
        window.closeMoreToolsMenu(menu);
        if (!window.openColorPickerModal()) {
            if (window.currentTool === "colorpicker") {
                window.currentTool = window.lastActiveTool;
            } else {
                window.colorPickerMode = "draw";
                window.currentTool = "colorpicker";
            }
        }
    }

    function handleToolbarStrokeWidthSelected(width, menu) {
        window.closeMoreToolsMenu(menu);
        window.updateActiveIntensity(width);
    }

    function runToolbarAction(action, menu) {
        window.closeMoreToolsMenu(menu);
        action();
    }

    function toggleMoreToolsMenu(buttonItem, menu, toolbar, contentItem) {
        if (menu.opened) {
            menu.close();
            return;
        }

        const pt = buttonItem.mapToItem(contentItem, 0, 0);
        if (toolbar.isVertical) {
            if (window.toolbarPosition === "right") {
                menu.x = pt.x - menu.width - Theme.spacingS;
            } else {
                menu.x = pt.x + buttonItem.width + Theme.spacingS;
            }
            const targetY = pt.y + (buttonItem.height - menu.height) / 2;
            menu.y = Math.max(Theme.spacingS, Math.min(targetY, contentItem.height - menu.height - Theme.spacingS));
        } else {
            const targetX = pt.x + (buttonItem.width - menu.width) / 2;
            menu.x = Math.max(Theme.spacingS, Math.min(targetX, contentItem.width - menu.width - Theme.spacingS));
            if (window.toolbarPosition === "bottom") {
                menu.y = pt.y - menu.height - Theme.spacingS;
            } else {
                menu.y = pt.y + buttonItem.height + Theme.spacingS;
            }
        }
        menu.open();
    }

    function positionBackdropPopover(popover, controlItem, toolbar, contentItem) {
        const pt = controlItem.mapToItem(contentItem, 0, 0);
        if (toolbar.isVertical) {
            if (window.toolbarPosition === "right") {
                popover.x = pt.x - popover.width - Theme.spacingXS;
            } else {
                popover.x = pt.x + controlItem.width + Theme.spacingXS;
            }
            popover.y = pt.y + (controlItem.height - popover.height) / 2;
            return;
        }

        popover.x = pt.x + (controlItem.width - popover.width) / 2;
        if (window.toolbarPosition === "bottom") {
            if (popover._anchorIsAbove !== undefined) {
                popover._anchorY = pt.y;
                popover._anchorIsAbove = true;
            } else {
                popover.y = pt.y - popover.height - Theme.spacingXS;
            }
        } else {
            if (popover._anchorIsAbove !== undefined) {
                popover._anchorY = pt.y + controlItem.height + Theme.spacingXS;
                popover._anchorIsAbove = false;
            } else {
                popover.y = pt.y + controlItem.height + Theme.spacingXS;
            }
        }
    }

    function handleBackdropControlHovered(popover, controlItem, toolbar, contentItem) {
        if (!popover) return;

        window.positionBackdropPopover(popover, controlItem, toolbar, contentItem);
        popover.open();
    }

    function handleBackdropControlExited(popover) {
        if (popover) {
            popover.startCloseTimer();
        }
    }

    function handleBackdropControlWheel(type, delta) {
        const step = delta > 0 ? 5 : -5;
        if (type === "padding") {
            window.backdropPadding = Math.max(10, Math.min(150, window.backdropPadding + step));
        } else if (type === "radius") {
            const rStep = delta > 0 ? 2 : -2;
            window.backdropCornerRadius = Math.max(0, Math.min(60, window.backdropCornerRadius + rStep));
        } else if (type === "shadow") {
            window.backdropShadowStrength = Math.max(0, Math.min(100, window.backdropShadowStrength + step));
        } else if (type === "angle") {
            const aStep = delta > 0 ? 15 : -15;
            window.backdropGradientAngle = (window.backdropGradientAngle + aStep + 360) % 360;
        } else if (type === "aspectRatio" && window.backdropAspectRatio === "custom") {
            const ratioStep = delta > 0 ? 5 : -5;
            const scaled = Math.round(window.customAspectRatio * 100) + ratioStep;
            window.customAspectRatio = Math.max(50, Math.min(250, scaled)) / 100.0;
        }
        window.requestActiveCanvasPaint();
    }

    content: Component {
        FocusScope {
            id: contentRoot
            focus: true
            implicitWidth: window.modalWidth
            implicitHeight: window.modalHeight

            Image {
                id: bgImage
                source: window.bgImageSource
                visible: false
                cache: false
                smooth: true
                mipmap: true

                Component.onCompleted: {
                    window.bgImageItem = bgImage;
                }

                onStatusChanged: {
                    if (status === Image.Ready) {
                        window.hasSampledContrast = false;
                        if (window.activeCanvas) {
                            window.activeCanvas.unloadImage(source);
                            window.activeCanvas.loadImage(source);
                        }
                        // bakedCanvas must also call loadImage so its onImageLoaded fires
                        // and triggers requestPaint — without this the background is never drawn
                        if (window.bakedCanvas) {
                            window.bakedCanvas.unloadImage(source);
                            window.bakedCanvas.loadImage(source);
                        }
                        contrastSampler.requestPaint();
                        offscreenSampler.requestPaint();
                    }
                }

            }

            Item {
                id: mainLayout
                anchors.fill: parent

                QuickCaptureToolbar {
                    id: toolbarCard
                    Component.onCompleted: window.toolbarItem = toolbarCard
                    z: 100
                    visible: window.toolbarVisible
                    pluginData: (window.parentWidget && window.parentWidget.pluginData) ? window.parentWidget.pluginData : ({})

                    anchors.top: window.toolbarPosition === "bottom" ? undefined : parent.top
                    anchors.bottom: window.toolbarPosition === "bottom" ? parent.bottom : undefined
                    anchors.left: window.toolbarPosition === "left" ? parent.left : undefined
                    anchors.right: window.toolbarPosition === "right" ? parent.right : undefined

                    anchors.horizontalCenter: (window.toolbarPosition === "top" || window.toolbarPosition === "bottom") ? parent.horizontalCenter : undefined
                    anchors.verticalCenter: (window.toolbarPosition === "left" || window.toolbarPosition === "right") ? parent.verticalCenter : undefined

                    anchors.margins: Theme.spacingM
                    isVertical: (window.toolbarPosition === "left" || window.toolbarPosition === "right")

                    showAnnotations: window.showAnnotations

                    currentTool: window.currentTool
                    activeToolType: window.effectiveTool
                    currentColor: window.currentColor
                    activeColorSlotIndex: window.activeColorSlotIndex

                    strokeWidth: window.activeIntensity
                    canUndo: window.canUndo
                    canRedo: window.canRedo

                    backdropMode: window.backdropMode
                    backdropSolidColor: window.backdropSolidColor
                    backdropGradientStart: window.backdropGradientStart
                    backdropGradientEnd: window.backdropGradientEnd
                    backdropGradientAngle: window.backdropGradientAngle
                    backdropPadding: window.backdropPadding
                    backdropCornerRadius: window.backdropCornerRadius
                    backdropShadowStrength: window.backdropShadowStrength
                    backdropAspectRatio: window.backdropAspectRatio
                    customAspectRatio: window.customAspectRatio
                    backdropAlignment: window.backdropAlignment
                    backdropColorPickingSlot: window.backdropColorPickingSlot

                    onChangeBackdropMode: (mode) => {
                        window.backdropMode = mode;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropSolidColor: (col) => {
                        window.backdropSolidColor = col;
                        window.hasUserCustomizedBackdrop = true;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onBackdropColorPickerRequested: (currentColor) => {
                        moreToolsMenu.close();
                        if (typeof PopoutService !== "undefined" && PopoutService && PopoutService.colorPickerModal) {
                            PopoutService.colorPickerModal.selectedColor = currentColor;
                            PopoutService.colorPickerModal.pickerTitle = I18n.tr("Choose Color");
                            PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                                if (window.backdropMode === "solid") {
                                    window.backdropSolidColor = selectedColor;
                                } else {
                                    const activeSlot = (window.toolbarItem ? window.toolbarItem.gradientActiveSlot : "start");
                                    if (activeSlot === "start") {
                                        window.backdropGradientStart = selectedColor;
                                    } else {
                                        window.backdropGradientEnd = selectedColor;
                                    }
                                }
                                window.hasUserCustomizedBackdrop = true;
                                if (window.activeCanvas) window.activeCanvas.requestPaint();
                            };
                            PopoutService.colorPickerModal.show();
                        }
                    }
                    onBackdropEyedropperRequested: (slot) => {
                        window.backdropColorPickingSlot = slot;
                        window.currentTool = "colorpicker";
                    }
                    onChangeBackdropGradientStart: (col) => {
                        window.backdropGradientStart = col;
                        window.hasUserCustomizedBackdrop = true;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropGradientEnd: (col) => {
                        window.backdropGradientEnd = col;
                        window.hasUserCustomizedBackdrop = true;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropGradientAngle: (angle) => {
                        window.backdropGradientAngle = angle;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropPadding: (pad) => {
                        window.backdropPadding = pad;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropCornerRadius: (r) => {
                        window.backdropCornerRadius = r;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropShadowStrength: (s) => {
                        window.backdropShadowStrength = s;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropAspectRatio: (ratio) => {
                        window.backdropAspectRatio = ratio;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeCustomAspectRatio: (ratio) => {
                        window.customAspectRatio = ratio;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropAlignment: (alignment) => {
                        window.backdropAlignment = alignment;
                        window.requestPaintAll();
                    }
                    onAutoColorBalanceRequested: {
                        window.backdropGradientStart = window.autoBackdropGradientStart;
                        window.backdropGradientEnd = window.autoBackdropGradientEnd;
                        window.backdropSolidColor = window.autoBackdropSolidColor;
                        window.hasUserCustomizedBackdrop = true;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }

                    onToolSelected: (tool) => {
                        window.handleToolbarToolSelected(tool, moreToolsMenu);
                    }
                    onColorSelected: (color, index) => {
                        window.handleToolbarColorSelected(color, index, moreToolsMenu);
                    }
                    onCustomColorPickerRequested: (buttonItem) => {
                        window.handleToolbarCustomColorPickerRequested(moreToolsMenu);
                    }
                    onStrokeWidthSelected: (width) => {
                        window.handleToolbarStrokeWidthSelected(width, moreToolsMenu);
                    }
                    onUndoRequested: {
                        window.runToolbarAction(window.performUndo, moreToolsMenu);
                    }
                    onRedoRequested: {
                        window.runToolbarAction(window.performRedo, moreToolsMenu);
                    }
                    onAnnotationsToggled: window.showAnnotations = !window.showAnnotations

                    onFloatRequested: {
                        window.runToolbarAction(captureActions.performFloatAction, moreToolsMenu);
                    }
                    onSaveRequested: {
                        window.runToolbarAction(captureActions.performSaveOnly, moreToolsMenu);
                    }

                    onCopyRequested: {
                        window.runToolbarAction(captureActions.performCopyOnly, moreToolsMenu);
                    }
                    onAnonymousCopyRequested: {
                        window.runToolbarAction(captureActions.performAnonymousCopy, moreToolsMenu);
                    }
                    onCopyAndSaveRequested: {
                        window.runToolbarAction(captureActions.performCopyAndSave, moreToolsMenu);
                    }
                    onCloseRequested: {
                        window.runToolbarAction(window.discardAndClose, moreToolsMenu);
                    }
                    onMoreToolsClicked: (buttonItem) => {
                        window.toggleMoreToolsMenu(buttonItem, moreToolsMenu, toolbarCard, contentRoot);
                    }
                    onBackdropControlHovered: (type, controlItem) => {
                        let popover = null;
                        if (type === "padding") popover = backdropPaddingPopover;
                        else if (type === "radius") popover = backdropRadiusPopover;
                        else if (type === "shadow") popover = backdropShadowPopover;
                        else if (type === "angle") popover = backdropAnglePopover;
                        else if (type === "aspectRatio") popover = backdropAspectRatioPopover;
                        else if (type === "alignment") popover = backdropAlignmentPopover;
                        else if (type === "presets") popover = backdropPresetsPopover;
                        window.handleBackdropControlHovered(popover, controlItem, toolbarCard, contentRoot);
                    }
                    onBackdropControlExited: (type) => {
                        let popover = null;
                        if (type === "padding") popover = backdropPaddingPopover;
                        else if (type === "radius") popover = backdropRadiusPopover;
                        else if (type === "shadow") popover = backdropShadowPopover;
                        else if (type === "angle") popover = backdropAnglePopover;
                        else if (type === "aspectRatio") popover = backdropAspectRatioPopover;
                        else if (type === "alignment") popover = backdropAlignmentPopover;
                        else if (type === "presets") popover = backdropPresetsPopover;
                        window.handleBackdropControlExited(popover);
                    }
                    onBackdropControlWheel: (type, delta) => {
                        window.handleBackdropControlWheel(type, delta);
                    }
                }

                // 2. Centered Canvas Board
                Item {
                    id: boardContainer
                    anchors.top: (window.toolbarVisible && window.toolbarPosition === "top") ? toolbarCard.bottom : parent.top
                    anchors.bottom: (window.toolbarVisible && window.toolbarPosition === "bottom") ? toolbarCard.top : parent.bottom
                    anchors.left: (window.toolbarVisible && window.toolbarPosition === "left") ? toolbarCard.right : parent.left
                    anchors.right: (window.toolbarVisible && window.toolbarPosition === "right") ? toolbarCard.left : parent.right
                    anchors.margins: Theme.spacingM

                    Component.onCompleted: {
                        window.boardContainerItem = boardContainer;
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 0
                    }

                    // Background Image Layer (Hardware Accelerated)
                    Item {
                        id: bgImageLayer
                        anchors.centerIn: parent
                        width: drawingCanvas.width
                        height: drawingCanvas.height
                        scale: drawingCanvas.scale
                        transformOrigin: drawingCanvas.transformOrigin
                        clip: true
                        visible: window.effectiveBackdropMode === "none"

                        Item {
                            id: transformedBgContainer
                            readonly property bool isRotated90: (window.bgRotation === 90 || window.bgRotation === 270)
                            readonly property real rawW: window.bgImageItem ? window.bgImageItem.sourceSize.width : 1
                            readonly property real rawH: window.bgImageItem ? window.bgImageItem.sourceSize.height : 1

                            width: (isRotated90 ? rawH : rawW) * window.editScale
                            height: (isRotated90 ? rawW : rawH) * window.editScale

                            x: window.hasActiveCropSelection ? -window.cropRect.x * window.editScale : 0
                            y: window.hasActiveCropSelection ? -window.cropRect.y * window.editScale : 0

                            Image {
                                id: staticBgImage
                                source: window.bgImageSource
                                cache: false
                                smooth: true
                                mipmap: true

                                anchors.centerIn: parent
                                width: transformedBgContainer.rawW * window.editScale
                                height: transformedBgContainer.rawH * window.editScale

                                rotation: window.bgRotation
                                transform: Scale {
                                    origin.x: staticBgImage.width / 2
                                    origin.y: staticBgImage.height / 2
                                    xScale: window.bgFlipH ? -1 : 1
                                    yScale: window.bgFlipV ? -1 : 1
                                }
                            }
                        }
                    }

                    Canvas {
                        id: bakedCanvas
                        anchors.centerIn: parent
                        scale: window.fitScale / window.editScale
                        transformOrigin: Item.Center
                        renderTarget: Canvas.Image
                        z: 1

                        width: window.canvasWidth * window.editScale
                        height: window.canvasHeight * window.editScale

                        layer.enabled: false

                        Component.onCompleted: {
                            window.bakedCanvas = bakedCanvas;
                        }

                        onImageLoaded: {
                            bakedCanvas.requestPaint();
                        }

                        onPaint: {
                            window.renderBakedCanvas(bakedCanvas, bgImage);
                        }
                    }

                    Canvas {
                        id: drawingCanvas
                        anchors.centerIn: parent
                        scale: window.fitScale / window.editScale
                        transformOrigin: Item.Center
                        renderTarget: Canvas.Image

                        z: 2

                        width: window.canvasWidth * window.editScale
                        height: window.canvasHeight * window.editScale

                        layer.enabled: false

                        Component.onCompleted: {
                            window.activeCanvas = drawingCanvas;
                        }

                        onImageLoaded: {
                            drawingCanvas.requestPaint();
                        }

                        onPaint: {
                            var ctx = drawingCanvas.getContext("2d");
                            ctx.clearRect(0, 0, drawingCanvas.width, drawingCanvas.height);
                            ctx.save();
                            ctx.scale(window.editScale, window.editScale);

                            // 1. Draw Dimming Selection Overlay (only if in crop/ocr/qr mode)
                            DrawingRenderer.drawSelectionOverlay(ctx, {
                                isCropMode: window.currentTool === "crop",
                                isOcrMode: window.currentTool === "ocr" || window.currentTool === "qr",
                                cropRect: window.cropRect,
                                ocrRect: window.ocrRect,
                                canvasWidth: window.canvasWidth,
                                canvasHeight: window.canvasHeight
                            }, Theme);

                            // 2. Draw active/selected annotations (translated in edit mode, or clipped in crop mode)
                            ctx.save();
                            const isBackdropActive = window.effectiveBackdropMode !== "none";
                            window.applyEditorAnnotationTransform(ctx, isBackdropActive);

                            if (window.showAnnotations) {
                                window.drawActiveAnnotationLayer(ctx);
                                window.drawTypingPreview(ctx);
                            }

                            ctx.restore();
                            ctx.restore();
                        }

                        // Mouse Drawing & Action Capture
                        DrawMouseArea {
                            id: drawMouseArea
                            anchors.fill: parent
                            window: rootWindow
                            drawingCanvas: drawingCanvas
                            previewTimer: previewTimer
                            magnifier: magnifier
                            radialMenu: radialMenu
                            textInputDialog: textInputDialog
                            moreToolsMenu: moreToolsMenu
                            stampOptionsToolbar: stampOptionsToolbar
                            textOptionsToolbar: textOptionsToolbar
                            lineOptionsToolbar: lineOptionsToolbar
                            arrowOptionsToolbar: arrowOptionsToolbar
                            redactOptionsToolbar: redactOptionsToolbar
                            calloutOptionsToolbar: calloutOptionsToolbar
                        }

                        SizePreviewCard {
                            id: sizePreviewItem
                            window: rootWindow
                            drawingCanvas: drawingCanvas
                        }
                    }

                    Rectangle {
                        id: canvasBorder
                        x: drawingCanvas.x - 1
                        y: drawingCanvas.y - 1
                        width: drawingCanvas.width + 2
                        height: drawingCanvas.height + 2
                        scale: drawingCanvas.scale
                        transformOrigin: drawingCanvas.transformOrigin
                        color: "transparent"
                        border.color: Theme.primary
                        border.width: 1.5 / drawingCanvas.scale
                        radius: Theme.cornerRadius / drawingCanvas.scale
                        z: 10
                        visible: (config.pluginData["showCanvasBorder"] !== undefined ? config.pluginData["showCanvasBorder"] : true) && (window.effectiveBackdropMode === "none")
                    }

                    Item {
                        id: canvasRoundedMask
                        width: drawingCanvas.width
                        height: drawingCanvas.height
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: "black"
                        }
                    }
                    TextInputDialog {
                        id: textInputDialog
                        window: rootWindow
                        modalFocusScope: modalFocusScope
                    }

                    Timer {
                        id: previewTimer
                        interval: 800
                        running: false
                        repeat: false
                        onTriggered: {
                            window.showSizePreview = false;
                        }
                    }

                    MagnifierLoupe {
                        id: magnifier
                        window: rootWindow
                        drawingCanvas: drawingCanvas
                        boardContainer: boardContainer
                        bgImage: bgImage
                        staticBgImage: staticBgImage
                        drawMouseArea: drawMouseArea
                    }
                }

                Canvas {
                    id: exportCanvas
                    visible: true
                    opacity: 0
                    x: -9999
                    y: -9999
                    z: 0
                    renderTarget: Canvas.Image
                    width: 1
                    height: 1

                    Component.onCompleted: {
                        window.exportCanvasItem = exportCanvas;
                    }

                    onPaint: {
                        window.renderExportCanvas(exportCanvas, bgImage);
                    }
                }

                RadialMenu {
                    id: radialMenu
                    presets: window.radialPresets
                    hoverTrigger: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.radialHoverTrigger !== undefined ? window.parentWidget.pluginData.radialHoverTrigger : false
                    hoverDelay: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.radialHoverDelay !== undefined ? window.parentWidget.pluginData.radialHoverDelay : 300
                    menuOpacity: (window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.radialMenuOpacity !== undefined ? window.parentWidget.pluginData.radialMenuOpacity : 100) / 100
                    onPresetSelected: (preset) => {
                        window.currentTool = preset.tool;
                        window.currentColor = preset.color;
                        const meta = Constants.getToolMeta(preset.tool);
                        const clamped = Math.max(meta.min, Math.min(meta.max, preset.thickness));
                        if (preset.tool === "text") window.textFontSize = clamped;
                        else if (preset.tool === "pixelate") window.pixelateIntensity = clamped;
                        else if (preset.tool === "spotlight") window.spotlightIntensity = clamped;
                        else if (preset.tool === "callout") window.calloutZoom = clamped;
                        else window.strokeWidth = clamped;
                        window.recordPresetUsage(preset);
                    }
                    onCenterClicked: {
                        window.currentTool = "select";
                    }
                }

                TextOptionsToolbar {
                    id: textOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    boldActive: window.textBold
                    italicActive: window.textItalic
                    underlineActive: window.textUnderline
                    backgroundActive: window.textBackground
                    onBoldToggled: window.textBold = !window.textBold
                    onItalicToggled: window.textItalic = !window.textItalic
                    onUnderlineToggled: window.textUnderline = !window.textUnderline
                    onBackgroundToggled: window.textBackground = !window.textBackground
                }

                StampOptionsToolbar {
                    id: stampOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    currentFormat: window.stampCounterFormat
                    onFormatSelected: (format) => window.stampCounterFormat = format
                }

                LineOptionsToolbar {
                    id: lineOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    currentStyle: window.activeLineStyle
                    onStyleSelected: (style) => window.activeLineStyle = style
                }

                ArrowOptionsToolbar {
                    id: arrowOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    currentLineStyle: window.activeArrowLineStyle
                    currentHeadStyle: window.activeArrowHeadStyle
                    onLineStyleSelected: (style) => window.activeArrowLineStyle = style
                    onHeadStyleSelected: (style) => window.activeArrowHeadStyle = style
                }

                RedactOptionsToolbar {
                    id: redactOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    currentMode: window.activeRedactMode
                    currentShape: window.activeRedactShape
                    onModeSelected: (mode) => window.activeRedactMode = mode
                    onShapeSelected: (shape) => window.activeRedactShape = shape
                }

                CalloutOptionsToolbar {
                    id: calloutOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    currentLinkLines: window.calloutLinkLines
                    currentShape: window.calloutShape
                    onLinkLinesSelected: (count) => window.calloutLinkLines = count
                    onShapeSelected: (shape) => window.calloutShape = shape
                }



                MoreToolsMenu {
                    id: moreToolsMenu
                    onRotateLeftRequested: window.rotateScreenshot("left")
                    onRotateRightRequested: window.rotateScreenshot("right")
                    onFlipHorizontalRequested: window.mirrorScreenshot("horizontal")
                    onFlipVerticalRequested: window.mirrorScreenshot("vertical")
                    onRotateRequested: window.rotateScreenshot("right")
                    onMirrorRequested: window.mirrorScreenshot("horizontal")
                    onOcrRequested: window.runOcr()
                    onQrScanRequested: window.runQrScan()
                    onEraserRequested: window.currentTool = "eraser"
                    onCopyColorRequested: {
                        window.colorPickerMode = "copy";
                        window.currentTool = "colorpicker";
                    }
                }



                PaletteWarningDialog {
                    id: paletteWarningDialog
                    Component.onCompleted: window.paletteWarningDialogRef = paletteWarningDialog
                    currentPaletteColors: toolbarCard.toolbarPalette
                    customPaletteColors: {
                        const customList = [];
                        const primaryRaw = config.pluginData["toolbar_color_primary"] || "primary";
                        const primaryColor = primaryRaw === "primary" ? Theme.primary : primaryRaw;
                        customList.push(typeof primaryColor === "string" ? Qt.color(primaryColor) : primaryColor);
                        for (let i = 0; i < 7; i++) {
                            const val = config.pluginData[`toolbar_color_${i}`] || config.adaptiveColors[i];
                            customList.push(typeof val === "string" ? Qt.color(val) : val);
                        }
                        return customList;
                    }
                    onCopyAndSwitch: {
                        window.switchPresetToCustom(true);
                    }
                    onSwitchOnly: {
                        window.switchPresetToCustom(false);
                    }
                }

                HoverSliderPopover {
                    id: backdropPaddingPopover
                    isVertical: toolbarCard.isVertical
                    minimum: 10
                    maximum: 150
                    value: window.backdropPadding
                    onUserValueChanged: (val) => {
                        window.backdropPadding = val;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                }

                HoverSliderPopover {
                    id: backdropRadiusPopover
                    isVertical: toolbarCard.isVertical
                    minimum: 0
                    maximum: 60
                    stepSize: 2
                    value: window.backdropCornerRadius
                    onUserValueChanged: (val) => {
                        window.backdropCornerRadius = val;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                }

                HoverSliderPopover {
                    id: backdropShadowPopover
                    isVertical: toolbarCard.isVertical
                    minimum: 0
                    maximum: 100
                    value: window.backdropShadowStrength
                    onUserValueChanged: (val) => {
                        window.backdropShadowStrength = val;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                }

                HoverSliderPopover {
                    id: backdropAnglePopover
                    isVertical: toolbarCard.isVertical
                    minimum: 0
                    maximum: 360
                    stepSize: 15
                    value: window.backdropGradientAngle
                    onUserValueChanged: (val) => {
                        window.backdropGradientAngle = val;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                }

                BackdropAspectRatioPopover {
                    id: backdropAspectRatioPopover
                    backdropAspectRatio: window.backdropAspectRatio
                    customAspectRatio: window.customAspectRatio
                    presets: window.aspectPresets

                    // Anchor-based positioning so popover stays correctly placed
                    // when height changes (e.g. customActive toggles the slider section)
                    property real _anchorY: 0
                    property bool _anchorIsAbove: false
                    y: _anchorIsAbove ? (_anchorY - height - Theme.spacingXS) : _anchorY

                    onChangeBackdropAspectRatio: (ratio) => {
                        window.backdropAspectRatio = ratio;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeCustomAspectRatio: (ratio) => {
                        window.customAspectRatio = ratio;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                }

                BackdropAlignmentPopover {
                    id: backdropAlignmentPopover
                    backdropAlignment: window.backdropAlignment
                    onChangeBackdropAlignment: (alignment) => {
                        window.backdropAlignment = alignment;
                        window.requestPaintAll();
                    }
                }

                BackdropPresetsPopover {
                    id: backdropPresetsPopover
                    presetsList: window.backdropPresets
                    onPresetSelected: (preset) => window.applyBackdropPreset(preset)
                    onSaveCurrentAsPreset: window.saveCurrentBackdropAsPreset()
                    onDeletePreset: (presetId) => window.deletePreset(presetId)
                    onUpdatePresetWithCurrent: (presetId) => window.updatePresetWithCurrent(presetId)
                    onRenamePreset: (presetId, newName) => window.renamePreset(presetId, newName)
                }

                Canvas {
                    id: contrastSampler
                    visible: false
                    width: 4
                    height: 4
                    onPaint: {
                        var ctx = contrastSampler.getContext("2d");
                        ctx.drawImage(bgImage, 0, 0, 4, 4, 0, 0, 4, 4);
                        var imgData = ctx.getImageData(0, 0, 4, 4);
                        if (imgData && imgData.data) {
                            // Sample center pixel (index 5) for luminance
                            var r = imgData.data[5 * 4];
                            var g = imgData.data[5 * 4 + 1];
                            var b = imgData.data[5 * 4 + 2];
                            var brightness = Helpers.getLuminance({ r: r/255, g: g/255, b: b/255 });
                            window.isScreenshotDark = (brightness < 0.35);
                            window.hasSampledContrast = true;

                            // Extract auto-balanced colors
                            var colors = Helpers.extractDominantColors(imgData, Qt);
                            window.autoBackdropGradientStart = colors.start;
                            window.autoBackdropGradientEnd = colors.end;
                            window.autoBackdropSolidColor = colors.start;
                        }
                    }
                }

                Canvas {
                    id: offscreenSampler
                    visible: false
                    width: window.bgImageItem ? window.bgImageItem.sourceSize.width : 1
                    height: window.bgImageItem ? window.bgImageItem.sourceSize.height : 1
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.drawImage(bgImage, 0, 0, width, height);
                    }
                    Component.onCompleted: {
                        window.offscreenSamplerItem = offscreenSampler;
                    }
                }
            }
        }
    }

    function openTypingDialog(dialog) {
        const targetDialog = dialog || textInputDialog;
        if (targetDialog) {
            targetDialog.open();
        }
    }

    function beginEditingTextStroke(stroke, dialog) {
        window.editingStroke = stroke;
        window.deselectStrokeForEditing(false);
        window.typingIsSpeechBubble = stroke.isSpeechBubble || false;

        // Store coordinates directly on the stroke to avoid cross-contamination
        // between concurrent edit sessions (multiple dialogs)
        stroke._editCoords = (stroke.isSpeechBubble && stroke.points.length >= 2)
            ? Qt.point(stroke.points[1].x, stroke.points[1].y)
            : Qt.point(stroke.points[0].x, stroke.points[0].y);
        window.typingCoords = stroke._editCoords;
        if (stroke.isSpeechBubble && stroke.points.length >= 2) {
            stroke._editTargetCoords = Qt.point(stroke.points[0].x, stroke.points[0].y);
            window.typingTargetCoords = stroke._editTargetCoords;
        }

        window.currentTypingText = stroke.text;
        window.typingCursorIndex = stroke.text ? stroke.text.length : 0;
        window.isTyping = true;
        window.currentColor = stroke.color;
        window.textFontSize = stroke.width;
        window.textBold = stroke.isBold;
        window.textItalic = stroke.isItalic;
        window.textUnderline = stroke.isUnderline;
        window.textBackground = stroke.hasBackground;
        window.textCornerRadius = stroke.cornerRadius;
        window.textFontFamily = stroke.fontFamily;
        window.openTypingDialog(dialog);
        window.repaintActiveCanvas();
    }

    function beginNewTextStroke(stroke, dialog) {
        const hasDrag = stroke.isSpeechBubble && stroke.points.length >= 2;
        window.typingIsSpeechBubble = hasDrag;
        window.typingCoords = hasDrag ? stroke.points[1] : stroke.points[0];
        if (hasDrag) {
            window.typingTargetCoords = stroke.points[0];
        }
        window.currentTypingText = "";
        window.typingCursorIndex = 0;
        window.isTyping = true;
        window.currentStroke = null;
        if (window.textInputMode === "popup") {
            window.openTypingDialog(dialog);
        }
        window.repaintActiveCanvas();
    }

    function getTypingStrokeStyle(textStr) {
        return {
            tool: "text",
            color: window.currentColor.toString(),
            width: window.textFontSize,
            isMonospace: window.textFontFamily === "monospace",
            fontFamily: window.textFontFamily,
            isBold: window.textBold,
            isItalic: window.textItalic,
            isUnderline: window.textUnderline,
            hasBackground: window.textBackground,
            cornerRadius: window.textCornerRadius,
            text: textStr
        };
    }

    function applyTypingStyleToStroke(stroke, textStr) {
        const style = window.getTypingStrokeStyle(textStr);
        stroke.text = style.text;
        stroke.color = style.color;
        stroke.width = style.width;
        stroke.isMonospace = style.isMonospace;
        stroke.fontFamily = style.fontFamily;
        stroke.isBold = style.isBold;
        stroke.isItalic = style.isItalic;
        stroke.isUnderline = style.isUnderline;
        stroke.hasBackground = style.hasBackground;
        stroke.cornerRadius = style.cornerRadius;
    }

    function replaceStrokeReference(stroke) {
        const idx = window.strokes.indexOf(stroke);
        if (idx !== -1) {
            const list = [...window.strokes];
            list[idx] = stroke;
            window.strokes = list;
        }
    }

    function removeTypingEditStroke() {
        const list = [...window.strokes];
        const idx = list.indexOf(window.editingStroke);
        if (idx !== -1) list.splice(idx, 1);
        window.strokes = list;
    }

    function updateTypingEditStroke(textStr) {
        const s = window.editingStroke;
        window.applyTypingStyleToStroke(s, textStr);

        // Use per-stroke saved coordinates to prevent cross-contamination
        // when multiple edit dialogs are open simultaneously
        const editCoords = s._editCoords || window.typingCoords;
        const editTargetCoords = s._editTargetCoords || window.typingTargetCoords;
        if (s.isSpeechBubble) {
            s.points = [editTargetCoords, editCoords];
        } else {
            s.points = [editCoords];
        }

        window.replaceStrokeReference(s);
        if (window.currentTool === "select") {
            window.selectedStroke = s;
        }

        delete s._editCoords;
        delete s._editTargetCoords;
    }

    function createTypingStroke(textStr) {
        const stroke = window.getTypingStrokeStyle(textStr);
        stroke.isSpeechBubble = window.typingIsSpeechBubble;
        stroke.points = window.typingIsSpeechBubble
            ? [Qt.point(window.typingTargetCoords.x, window.typingTargetCoords.y), Qt.point(window.typingCoords.x, window.typingCoords.y)]
            : [Qt.point(window.typingCoords.x, window.typingCoords.y)];
        window.pushStroke(stroke);
    }

    function finishTypingSession() {
        window.currentTypingText = "";
        window.isTyping = false;
        window.repaintActiveCanvas();
    }

    function commitTypingText() {
        if (!window.isTyping) return;
        const textStr = window.currentTypingText.trim();
        if (window.editingStroke) {
            if (textStr.length > 0) {
                window.updateTypingEditStroke(textStr);
            } else {
                window.removeTypingEditStroke();
            }
            window.editingStroke = null;
        } else if (textStr.length > 0) {
            window.createTypingStroke(textStr);
        }
        window.finishTypingSession();
    }

    function pushStroke(stroke) {
        const list = [...window.strokes];
        list.push(stroke);
        window.strokes = list;
        window.undoneStrokes = [];
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }

    function performUndo() {
        if (window.strokes.length > 0) {
            const list = [...window.strokes];
            const popped = list.pop();
            window.strokes = list;
            window.undoneStrokes = [...window.undoneStrokes, popped];
            if (window.selectedStroke === popped) {
                window.deselectStrokeForEditing(true);
            }
            if (window.activeCanvas) window.activeCanvas.requestPaint();
        }
    }

    function performRedo() {
        if (window.undoneStrokes.length > 0) {
            const undoneList = [...window.undoneStrokes];
            const strokeToRedo = undoneList.pop();
            window.undoneStrokes = undoneList;
            window.strokes = [...window.strokes, strokeToRedo];

            if (window.currentTool === "select") {
                window.selectStrokeForEditing(strokeToRedo, !window.selectedStroke);
            }

            if (window.activeCanvas) window.activeCanvas.requestPaint();
        }
    }

    function discardAndClose() {
        window.deselectStrokeForEditing(false);
        window.copiedStroke = null;
        window.pastePreviewActive = false;
        window.close();
    }

    onDialogClosed: {
        if (window.floatService) {
            window.floatService.showAllWindows();
        }
        // Reset path state here (not in onOpened) so re-fires during layout/screen changes
        // don't wipe bgImageSource before the image has a chance to render.
        window.currentCapturePath = "";
        window.restoreSource = "";
        window.bgImageSource = "";
        window.exportCallback = null;
    }

    Component.onCompleted: {
        window.loadPresetsFromPluginData();
    }
}
