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

local pxItr <const> = image:pixels()
for pixel in pxItr do
    if not mask:contains(
            xMask + pixel.x,
            yMask + pixel.y) then
        pixel(alphaIndex)
    end
end

local brushPattern = app.preferences.brush.pattern
local center = Point(wMask // 2, hMask // 2)
if site.layer and site.layer.isTilemap then
    brushPattern = BrushPattern.NONE
end

if app.preferences.document(sprite).grid.snap then
    center = Point(0, 0)
end

app.transaction("Brush From Mask", function()
    sprite.selection:deselect()
    app.brush = Brush {
        type = BrushType.IMAGE,
        image = image,
        pattern = brushPattern,
        center = center
    }
    app.tool = "pencil"
end)