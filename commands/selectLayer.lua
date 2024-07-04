dofile("../support/aseutilities.lua")

local sprite <const> = app.sprite
if not sprite then return end

local frObj <const> = app.frame
if not frObj then return end

local editor <const> = app.editor
if not editor then return end

local mouse <const> = editor.spritePos
local xMouse <const> = mouse.x
local yMouse <const> = mouse.y

if xMouse < 0 or yMouse < 0 then return end

local specSprite <const> = sprite.spec
local wSprite <const> = specSprite.width
local hSprite <const> = specSprite.height

if xMouse >= wSprite or yMouse >= hSprite then return end

local colorMode <const> = specSprite.colorMode
local alphaIndex <const> = specSprite.transparentColor
local isRgb <const> = colorMode == ColorMode.RGB
local isGry <const> = colorMode == ColorMode.GRAY
local isIdx <const> = colorMode == ColorMode.INDEXED

local palette <const> = AseUtilities.getPalette(frObj, sprite.palettes)
local lenPalette <const> = #palette

local layers <const> = AseUtilities.getLayerHierarchy(
    sprite, true, false, true, true)
local lenLayers <const> = #layers

local max <const> = math.max
local abs <const> = math.abs
local strsub <const> = string.sub
local strunpack <const> = string.unpack
local pxTilei <const> = app.pixelColor.tileI

local i = lenLayers + 1
while i > 1 do
    i = i - 1
    local layer <const> = layers[i]
    local cel <const> = layer:cel(frObj)
    if cel then
        local celPos <const> = cel.position
        local xtlCel <const> = celPos.x
        local ytlCel <const> = celPos.y
        if xMouse >= xtlCel and yMouse >= ytlCel then
            local wTile = 1
            local hTile = 1

            local isTileMap <const> = layer.isTilemap
            local tileSet = nil
            local lenTileSet = 0

            if isTileMap then
                tileSet = layer.tileset
                if tileSet then
                    local tileGrid <const> = tileSet.grid
                    local tileSize <const> = tileGrid.tileSize
                    wTile = max(1, abs(tileSize.width))
                    hTile = max(1, abs(tileSize.height))
                    lenTileSet = #tileSet
                end
            end

            local image <const> = cel.image
            local specImage <const> = image.spec
            local wImage <const> = specImage.width
            local hImage <const> = specImage.height

            local xbrCel <const> = xtlCel + wImage * wTile - 1
            local ybrCel <const> = ytlCel + hImage * hTile - 1

            if xMouse <= xbrCel and yMouse <= ybrCel then
                local xLocal <const> = xMouse - xtlCel
                local yLocal <const> = yMouse - ytlCel

                local aLayer8 <const> = layer.opacity or 255
                local aCel8 <const> = cel.opacity
                local aComp01 <const> = (aLayer8 / 255.0) * (aCel8 / 255.0)

                local bytesStr <const> = image.bytes
                local bpp <const> = image.bytesPerPixel
                local unpackFmt <const> = "I" .. bpp

                local isNonZero = false
                if isTileMap then
                    -- Coordinates within tile image would be xLocal % wTile
                    -- and yLocal % hTile.
                    local xMap <const> = xLocal // wTile
                    local yMap <const> = yLocal // hTile

                    local dataIdx <const> = (yMap * wImage + xMap) * bpp
                    local dataStr <const> = strsub(bytesStr,
                        1 + dataIdx, bpp + dataIdx)

                    local tileEntry <const> = strunpack(unpackFmt, dataStr)
                    local tileIndex <const> = pxTilei(tileEntry)

                    if tileIndex > 0 and tileIndex < lenTileSet
                        and aComp01 > 0.0 then
                        -- For tile maps, this is good enough. Otherwise,
                        -- you have to deal with flags in the image map
                        -- that have flipped or rotated the tile image.
                        isNonZero = true
                    end
                else
                    local dataIdx <const> = (yLocal * wImage + xLocal) * bpp
                    local dataStr <const> = strsub(bytesStr,
                        1 + dataIdx, bpp + dataIdx)
                    local dataInt <const> = strunpack(unpackFmt, dataStr)

                    if isRgb then
                        local a8 <const> = (dataInt >> 0x18) & 0xff
                        local a01 <const> = aComp01 * (a8 / 255.0)
                        isNonZero = a01 > 0.0
                    elseif isGry then
                        local a8 <const> = (dataInt >> 0x08) & 0xff
                        local a01 <const> = aComp01 * (a8 / 255.0)
                        isNonZero = a01 > 0.0
                    elseif isIdx then
                        if dataInt ~= alphaIndex
                            and dataInt >= 0 and dataInt < lenPalette then
                            local aseColor <const> = palette:getColor(dataInt)
                            local a8 <const> = aseColor.alpha
                            local a01 <const> = aComp01 * (a8 / 255.0)
                            isNonZero = a01 > 0.0
                        end
                    end
                end

                if isNonZero then
                    app.layer = layer
                    app.refresh()
                    return
                end -- End pixel is not transparent.
            end     -- End mouse within upper bound.
        end         -- End mouse within lower bound.
    end             -- End cel is not nil.
end                 -- End layers loop.