dofile("../support/aseutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local mask <const>, isValid <const> = AseUtilities.getSelection(sprite)
if not isValid then return end

local frame <const> = site.frame or sprite.frames[1]

local maskBounds <const> = mask.bounds
local xMask <const> = maskBounds.x
local yMask <const> = maskBounds.y
local wMask <const> = math.max(1, math.abs(maskBounds.width))
local hMask <const> = math.max(1, math.abs(maskBounds.height))

local spriteSpec <const> = sprite.spec
local colorMode <const> = spriteSpec.colorMode
local colorSpace <const> = spriteSpec.colorSpace
local alphaIndex <const> = spriteSpec.transparentColor

local imageSpec <const> = AseUtilities.createSpec(
    wMask, hMask,
    colorMode, colorSpace, alphaIndex)
local image <const> = Image(imageSpec)
image:drawSprite(sprite, frame, Point(-xMask, -yMask))

-- Alpha index can behave funnily when palette is malformed, but
-- not sure what can be done about it.
if alphaIndex >= 0 and alphaIndex < 256 then
    local pxItr <const> = image:pixels()
    for pixel in pxItr do
        if not mask:contains(
                xMask + pixel.x,
                yMask + pixel.y) then
            pixel(alphaIndex)
        end
    end
end

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

local center = Point(wMask // 2, hMask // 2)
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
                center = Point(wMask // 2, 0)
            elseif maskPivot == 2 then
                center = Point(wMask - 1, 0)
            elseif maskPivot == 3 then
                center = Point(0, hMask // 2)
            elseif maskPivot == 4 then
                center = Point(wMask // 2, hMask // 2)
            elseif maskPivot == 5 then
                center = Point(wMask - 1, hMask // 2)
            elseif maskPivot == 6 then
                center = Point(0, hMask - 1)
            elseif maskPivot == 7 then
                center = Point(wMask // 2, hMask - 1)
            elseif maskPivot == 8 then
                center = Point(wMask - 1, hMask - 1)
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
        patternOrigin = Point(xMask, yMask),
    }
    app.tool = "pencil"
end)

app.refresh()