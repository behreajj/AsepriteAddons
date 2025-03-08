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
local useSnap = false
if appPrefs then
    local docPrefs <const> = appPrefs.document(sprite)
    if docPrefs then
        local gridPrefs <const> = docPrefs.grid
        if gridPrefs then
            local snapPref <const> = gridPrefs.snap --[[@as boolean]]
            if snapPref then
                useSnap = snapPref
            end
        end
    end
end

-- Ideally, this would also turn off strict tile alignment mode,
-- but unsure how to do this, as there's only the command to toggle,
-- not a preference for the document's current state.
local brushPattern = BrushPattern.NONE
if site.layer and site.layer.isTilemap then
    if useSnap then
        brushPattern = BrushPattern.TARGET
    else
        brushPattern = BrushPattern.ORIGIN
    end
end

local centerPreset = "CENTER"
if useSnap then
    centerPreset = "TOP_LEFT"
else
    if appPrefs then
        local maskPrefs <const> = appPrefs.selection
        if maskPrefs then
            -- https://github.com/aseprite/aseprite/blob/main/data/pref.xml#L81
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
    end         -- App preferencs exists.
end             -- Use snap check.

app.transaction("Brush From Mask", function()
    if appPrefs then
        local brushPrefs <const> = appPrefs.brush
        if brushPrefs then
            brushPrefs.pattern = brushPattern
        end
    end

    sprite.selection:deselect()
    app.brush = AseUtilities.imageToBrush(
        image, centerPreset, brushPattern, xSel, ySel)
    app.tool = "pencil"
end)

app.refresh()