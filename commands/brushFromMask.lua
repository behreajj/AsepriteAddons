dofile("../support/aseutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local sel <const>, isValid <const> = AseUtilities.getSelection(sprite)
if not isValid then return end

local frame <const> = site.frame or sprite.frames[1]
local image <const>, xSel <const>, ySel <const> = AseUtilities.imageFromSel(
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

local wImage <const> = image.width
local hImage <const> = image.height
local center = Point(wImage // 2, hImage // 2)
if useSnap then
    center = Point(0, 0)
else
    if appPrefs then
        local maskPrefs <const> = appPrefs.selection
        if maskPrefs then
            -- https://github.com/aseprite/aseprite/blob/main/data/pref.xml#L81
            local maskPivot <const> = maskPrefs.pivot_position --[[@as integer]]
            if maskPivot == 0 then
                center = Point(0, 0)
            elseif maskPivot == 1 then
                center = Point(wImage // 2, 0)
            elseif maskPivot == 2 then
                center = Point(wImage - 1, 0)
            elseif maskPivot == 3 then
                center = Point(0, hImage // 2)
            elseif maskPivot == 4 then
                center = Point(wImage // 2, hImage // 2)
            elseif maskPivot == 5 then
                center = Point(wImage - 1, hImage // 2)
            elseif maskPivot == 6 then
                center = Point(0, hImage - 1)
            elseif maskPivot == 7 then
                center = Point(wImage // 2, hImage - 1)
            elseif maskPivot == 8 then
                center = Point(wImage - 1, hImage - 1)
            end
        end
    end
end

app.transaction("Brush From Mask", function()
    if appPrefs then
        local brushPrefs <const> = appPrefs.brush
        if brushPrefs then
            brushPrefs.pattern = brushPattern
        end
    end

    sprite.selection:deselect()
    app.brush = Brush {
        type = BrushType.IMAGE,
        image = image,
        center = center,
        pattern = brushPattern,
        patternOrigin = Point(xSel, ySel),
    }
    app.tool = "pencil"
end)

app.refresh()