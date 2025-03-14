dofile("../support/aseutilities.lua")

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
    if brushType == BrushType.IMAGE
        or brushType == BrushType.CIRCLE then
        return
    end

    local fillColor <const> = AseUtilities.aseColorCopy(app.fgColor, "")
    if fillColor.alpha <= 0 then return end

    local query <const> = AseUtilities.DIMETRIC_ANGLES[brushDegrees]
    local brushRadians <const> = query
        or (0.017453292519943 * brushDegrees)

    local cosa <const> = math.cos(brushRadians)
    local sina <const> = math.sin(brushRadians)
    local rotPeriodDegrees <const> = brushType == BrushType.SQUARE
        and 90 or (brushType == BrushType.LINE and 180 or 0)
    local rotNeeded <const> = brushDegrees % rotPeriodDegrees ~= 0

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
    context.antialias = false
    context.color = fillColor

    -- Assume no antialiasing, so floor center.
    local xCenterf = wTrgi * 0.5
    local yCenterf = hTrgi * 0.5
    local xCenteri <const> = math.floor(xCenterf + 0.5)
    local yCenteri <const> = math.floor(yCenterf + 0.5)
    local sizeHalfReal <const> = brushSize * 0.5

    if brushType == BrushType.SQUARE then
        if rotNeeded then
            local cosaSzHf <const> = cosa * sizeHalfReal
            local sinaSzHf <const> = sina * sizeHalfReal

            context:beginPath()
            context:moveTo(
                math.floor(xCenteri - cosaSzHf + sinaSzHf),
                math.floor(yCenteri + cosaSzHf + sinaSzHf))
            context:lineTo(
                math.floor(xCenteri + cosaSzHf + sinaSzHf),
                math.floor(yCenteri + cosaSzHf - sinaSzHf))
            context:lineTo(
                math.floor(xCenteri + cosaSzHf - sinaSzHf),
                math.floor(yCenteri - cosaSzHf - sinaSzHf))
            context:lineTo(
                math.floor(xCenteri - cosaSzHf - sinaSzHf),
                math.floor(yCenteri - cosaSzHf + sinaSzHf))
            context:closePath()
            context:fill()
        else
            image:clear(fillColor)
        end
    elseif brushType == BrushType.LINE then
        local cosaSzHf <const> = cosa * sizeHalfReal
        local sinaSzHf <const> = sina * sizeHalfReal

        context:beginPath()
        context:moveTo(
            xCenteri - cosaSzHf,
            yCenteri + sinaSzHf)
        context:lineTo(
            xCenteri + cosaSzHf,
            yCenteri - sinaSzHf)
        context:stroke()
    end

    app.brush = AseUtilities.imageToBrush(image, centerPreset)
    app.tool = "pencil"
    app.refresh()
    return
end

local frame <const> = site.frame or sprite.frames[1]
local image <const>, xSel <const>, ySel <const> = AseUtilities.selToImage(
    sel, sprite, frame.frameNumber)

-- Ideally, this would also turn off strict tile alignment mode,
-- but unsure how to do this, as there's only the command to toggle,
-- not a preference for the document's current state.
local brushPattern = BrushPattern.NONE

-- You could change these to tile map top left corner, but the problem is
-- when the selection size doesn't match up to tile dimensions.
local xPattern = xSel
local yPattern = ySel

local activeLayer <const> = site.layer
if activeLayer and activeLayer.isTilemap then
    if useGridSnap then
        brushPattern = BrushPattern.TARGET
    else
        brushPattern = BrushPattern.ORIGIN
    end
end

if not useTopleft and appPrefs then
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
    if appPrefs then
        local brushPrefs <const> = appPrefs.brush
        if brushPrefs then
            brushPrefs.pattern = brushPattern
        end
    end

    sprite.selection:deselect()
    app.brush = AseUtilities.imageToBrush(
        image, centerPreset, brushPattern, xPattern, yPattern)

    -- Setting to pencil may be disruptive if the user is using, e.g., the
    -- eraser, but given the variety of brush previews, and the issues with
    -- those previews, this seems like the best choice.
    app.tool = "pencil"
end)

app.refresh()