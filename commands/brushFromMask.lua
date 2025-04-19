dofile("../support/shapeutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local appPrefs <const> = app.preferences
local useGridSnap = false
local cursorSnap = false
if appPrefs then
    local cursorPrefs <const> = appPrefs.cursor
    if cursorPrefs then
        local snapToGrid <const> = cursorPrefs.snap_to_grid
        if snapToGrid then
            cursorSnap = true
        end
    end

    local docPrefs <const> = appPrefs.document(sprite)
    if docPrefs then
        local gridPrefs <const> = docPrefs.grid
        if gridPrefs then
            local snapPref <const> = gridPrefs.snap --[[@as boolean]]
            if snapPref then
                useGridSnap = snapPref
            end -- End snap prefs exists.
        end     -- End grid prefs exists.
    end         -- End doc prefs exists.
end             -- End preferences exists.

local useTopleft <const> = (not cursorSnap) and useGridSnap
local centerPreset = useTopleft and "TOP_LEFT" or "CENTER"

local sel <const>, isValid <const> = AseUtilities.getSelection(sprite)
if not isValid then
    -- Instead of returning when selection is not valid,
    -- try to correct issues with built-in square brush.

    local brush <const> = app.brush

    local brushType <const> = brush.type
    local brushSize <const> = brush.size
    local brushDegrees <const> = brush.angle

    if brushSize <= 1 then return end
    if brushType == BrushType.IMAGE then
        return
    end

    -- Indexed color mode brushes seem to have a bug where the fill color
    -- is calculated relative to the alpha index, so 1 becomes 24
    -- if the alpha index is 23.
    local fillColor <const> = AseUtilities.aseColorCopy(app.fgColor, "")
    if fillColor.alpha <= 0 then return end

    local query <const> = AseUtilities.DIMETRIC_ANGLES[brushDegrees]
    local brushRadians <const> = query
        or (0.017453292519943 * brushDegrees)

    local isCircle <const> = brushType == BrushType.CIRCLE
    local rotPeriodDegrees <const> = brushType == BrushType.SQUARE
        and 90 or (brushType == BrushType.LINE and 180 or 1)
    local rotNeeded <const> = (not isCircle)
        and brushDegrees % rotPeriodDegrees ~= 0
    local cosa <const> = rotNeeded and math.cos(brushRadians) or 1.0
    local sina <const> = rotNeeded and math.sin(brushRadians) or 0.0

    -- Calculate needed size of image to rotate image.
    local wTrgi = brushSize
    local hTrgi = brushSize
    if rotNeeded then
        local absCosa <const> = math.abs(cosa)
        local absSina <const> = math.abs(sina)
        wTrgi = math.ceil(brushSize * absSina + brushSize * absCosa)
        hTrgi = math.ceil(brushSize * absCosa + brushSize * absSina)
    end

    local spriteSpec <const> = sprite.spec
    local image <const> = Image(AseUtilities.createSpec(
        wTrgi, hTrgi,
        spriteSpec.colorMode,
        spriteSpec.colorSpace,
        spriteSpec.transparentColor))

    local context <const> = image.context
    if not context then return end

    local xCenteri <const> = math.floor(wTrgi * 0.5 + 0.5)
    local yCenteri <const> = math.floor(hTrgi * 0.5 + 0.5)
    local sizeHalfReal <const> = brushSize * 0.5

    local pixelRatio <const> = sprite.pixelRatio
    local wPixel <const> = math.max(1, math.abs(pixelRatio.width))
    local hPixel <const> = math.max(1, math.abs(pixelRatio.height))
    local shortPixel <const> = math.min(wPixel, hPixel)

    local xSize = sizeHalfReal
    local ySize = sizeHalfReal
    if wPixel ~= hPixel then
        if wPixel == shortPixel then
            ySize = ySize * (wPixel / hPixel)
        elseif hPixel == shortPixel then
            xSize = xSize * (hPixel / wPixel)
        end
    end

    if brushType == BrushType.SQUARE then
        local xCosaSzHf <const> = cosa * xSize
        local xSinaSzHf <const> = sina * xSize
        local ySinaSzHf <const> = sina * ySize
        local yCosaSzHf <const> = cosa * ySize

        context.antialias = false
        context.color = fillColor
        context:beginPath()
        context:moveTo(
            math.floor(xCenteri - xCosaSzHf + xSinaSzHf),
            math.floor(yCenteri + yCosaSzHf + ySinaSzHf))
        context:lineTo(
            math.floor(xCenteri + xCosaSzHf + xSinaSzHf),
            math.floor(yCenteri + yCosaSzHf - ySinaSzHf))
        context:lineTo(
            math.floor(xCenteri + xCosaSzHf - xSinaSzHf),
            math.floor(yCenteri - yCosaSzHf - ySinaSzHf))
        context:lineTo(
            math.floor(xCenteri - xCosaSzHf - xSinaSzHf),
            math.floor(yCenteri - yCosaSzHf + ySinaSzHf))
        context:closePath()
        context:fill()
    elseif brushType == BrushType.LINE then
        local xCosaSize <const> = cosa * xSize
        local ySinaSize <const> = sina * ySize

        context.antialias = false
        context.color = fillColor
        context:beginPath()
        context:moveTo(xCenteri - xCosaSize, yCenteri + ySinaSize)
        context:lineTo(xCenteri + xCosaSize, yCenteri - ySinaSize)
        context:stroke()
    elseif brushType == BrushType.CIRCLE then
        -- TODO: This has uneven dimensions.
        ShapeUtilities.drawEllipse(
            context,
            xCenteri, yCenteri,
            xSize, ySize,
            true, fillColor,
            false, Color(), 0,
            false)
    end

    AseUtilities.setBrush(AseUtilities.imageToBrush(image, centerPreset))

    app.refresh()
    return
end

local frame <const> = site.frame or sprite.frames[1]
local image <const>, xSel <const>, ySel <const> = AseUtilities.selToImage(
    sel, sprite, frame.frameNumber)

-- You could change these to tile map top left corner, but the problem is
-- when the selection size doesn't match up to tile dimensions.
local xPattern = xSel
local yPattern = ySel

local brushPattern = BrushPattern.NONE
local activeLayer <const> = site.layer
if activeLayer and activeLayer.isTilemap then
    if useGridSnap then
        brushPattern = BrushPattern.TARGET
    else
        brushPattern = BrushPattern.ORIGIN
    end
end

if (not useTopleft) and appPrefs then
    -- https://github.com/aseprite/aseprite/blob/main/data/pref.xml#L81
    local maskPrefs <const> = appPrefs.selection
    if maskPrefs then
        local maskPivot <const> = maskPrefs.pivot_position --[[@as integer]]
        if maskPivot then
            local centerPresets <const> = {
                "TOP_LEFT", "TOP_CENTER", "TOP_RIGHT",
                "CENTER_LEFT", "CENTER", "CENTER_RIGHT",
                "BOTTOM_LEFT", "BOTTOM_CENTER", "BOTTOM_RIGHT"
            }
            centerPreset = centerPresets[1 + maskPivot % #centerPresets]
        end -- Mask pivot exists.
    end     -- Mask preferences exists.
end         -- Use grid snap check.

app.transaction("Brush From Mask", function()
    sprite.selection:deselect()
    AseUtilities.setBrush(AseUtilities.imageToBrush(
        image, centerPreset, brushPattern, xPattern, yPattern))
end)

app.refresh()