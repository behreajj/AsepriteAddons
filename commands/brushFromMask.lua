dofile("../support/aseutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local sel <const>, isValid <const> = AseUtilities.getSelection(sprite)
if not isValid then return end

local frame <const> = site.frame or sprite.frames[1]
local image <const>, xSel <const>, ySel <const> = AseUtilities.selToImage(
    sel, sprite, frame.frameNumber)

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

local centerPreset = "CENTER"
if (not cursorSnap) and useGridSnap then
    centerPreset = "TOP_LEFT"
elseif appPrefs then
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
        end     -- Mask pivot exists.
    end         -- Mask preferences exists.
end             -- Use grid snap check.

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
    app.tool = "pencil"
end)

app.refresh()