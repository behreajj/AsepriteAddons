dofile("../../support/aseutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local frame <const> = site.frame
if not frame then return end

local clipboard <const> = app.clipboard
local cbContent <const> = clipboard.content
local cbImg <const> = cbContent.image

local trgImg = cbImg
local xtl, ytl = 0, 0
local centerOnMouse = false

-- Paste to range frames instead of individual frame?
-- If so, would have to acquire range frames immediately.
-- Also problem if frIdcs is empty...

local spriteSpec <const> = sprite.spec
local spriteColorMode <const> = spriteSpec.colorMode

if (not cbImg) or cbImg:isEmpty() then
    local sel <const>, isValid <const> = AseUtilities.getSelection(sprite)

    if isValid then
        local selImg <const>,
        xSel <const>,
        ySel <const> = AseUtilities.selToImage(sel, sprite, frame.frameNumber)

        trgImg = selImg
        xtl = xSel
        ytl = ySel
    else
        -- local layer <const> = site.layer
        -- if not layer then return end
        -- if layer.isReference then return end
        -- local cel <const> = layer:cel(frame)
        -- if not cel then return end

        -- if layer.isTilemap then
        --     local tileSet <const> = layer.tileset
        --     if not tileSet then return end
        --     trgImg = AseUtilities.tileMapToImage(
        --         cel.image, tileSet, spriteColorMode)
        -- else
        --     trgImg = cel.image
        -- end

        -- local celPos <const> = cel.position
        -- xtl = celPos.x
        -- ytl = celPos.y
    end
else
    centerOnMouse = true
end

if (not trgImg) or trgImg:isEmpty() then return end

local useTrim = true
if useTrim then
    local trimmed <const>,
    xTrim <const>,
    yTrim <const> = AseUtilities.trimImageAlpha(trgImg, 0,
        trgImg.spec.transparentColor)
    trgImg = trimmed
    xtl = xtl + xTrim
    ytl = ytl + yTrim
end

local trgImgSpec <const> = trgImg.spec
local trgColorMode <const> = trgImgSpec.colorMode

if trgColorMode ~= spriteColorMode then
    if spriteColorMode == ColorMode.RGB
        and trgColorMode == ColorMode.INDEXED then
        local palette <const> = cbContent.palette
        if not palette then return end
        local lenPalette <const> = #palette

        local srcBytes <const> = trgImg.bytes
        -- TODO: Implement.

        return
    else
        return
    end
end

local wSprite <const> = spriteSpec.width
local hSprite <const> = spriteSpec.height
local wTrgImg <const> = trgImgSpec.width
local hTrgImg <const> = trgImgSpec.height

xtl = math.floor((wSprite - wTrgImg) * 0.5)
ytl = math.floor((hSprite - hTrgImg) * 0.5)

if centerOnMouse then
    local xMouse <const>, yMouse <const> = AseUtilities.getMouse()
    if xMouse >= 0 and xMouse < spriteSpec.width
        and yMouse >= 0 and yMouse < spriteSpec.height then
        xtl = math.floor(xMouse - wTrgImg * 0.5)
        ytl = math.floor(yMouse - hTrgImg * 0.5)
    end
end

app.transaction("Paste to New Layer", function()
    local srcLayer <const> = site.layer
    local parent <const> = srcLayer
        and srcLayer.parent
        or sprite
    local trgLayer <const> = sprite:newLayer()
    trgLayer.name = "From Clipboard"
    trgLayer.parent = parent

    local trgCelPos <const> = Point(xtl, ytl)
    sprite:newCel(trgLayer, frame, trgImg, trgCelPos)
    app.layer = srcLayer
end)

app.refresh()