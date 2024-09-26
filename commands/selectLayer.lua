dofile("../support/aseutilities.lua")

local sprite <const> = app.sprite
if not sprite then return end

local frObj <const> = app.frame
if not frObj then return end

local xMouse <const>, yMouse <const> = AseUtilities.getMouse()

if xMouse < 0 or yMouse < 0 then return end

local specSprite <const> = sprite.spec
local wSprite <const> = specSprite.width
local hSprite <const> = specSprite.height

if xMouse >= wSprite or yMouse >= hSprite then return end

---@param x integer
---@param y integer
---@param wImage integer
---@param colorMode ColorMode
---@param bpp integer
---@param bytesStr string
---@param aComp01 number
---@param alphaIndex integer
---@param palette Palette
---@return boolean
local function eval(
    x, y, wImage, colorMode, bpp, bytesStr, aComp01, alphaIndex, palette)
    local dataIdx <const> = (y * wImage + x) * bpp
    local dataStr <const> = string.sub(bytesStr,
        1 + dataIdx, bpp + dataIdx)
    local dataInt <const> = string.unpack("<I" .. bpp, dataStr)

    if colorMode == ColorMode.RGB then
        local a8 <const> = (dataInt >> 0x18) & 0xff
        local a01 <const> = aComp01 * (a8 / 255.0)
        return a01 > 0.0
    elseif colorMode == ColorMode.GRAY then
        local a8 <const> = (dataInt >> 0x08) & 0xff
        local a01 <const> = aComp01 * (a8 / 255.0)
        return a01 > 0.0
    elseif colorMode == ColorMode.INDEXED then
        if dataInt ~= alphaIndex
            and dataInt >= 0 and dataInt < #palette then
            local aseColor <const> = palette:getColor(dataInt)
            local a8 <const> = aseColor.alpha
            local a01 <const> = aComp01 * (a8 / 255.0)
            return a01 > 0.0
        end
    end
    return false
end

local colorMode <const> = specSprite.colorMode
local alphaIndex <const> = specSprite.transparentColor

local palette <const> = AseUtilities.getPalette(frObj, sprite.palettes)

local max <const> = math.max
local abs <const> = math.abs
local strsub <const> = string.sub
local strunpack <const> = string.unpack

local appendLeaves <const> = AseUtilities.appendLeaves
local bakeFlag <const> = AseUtilities.bakeFlag
local pxTilei <const> = app.pixelColor.tileI
local pxTilef <const> = app.pixelColor.tileF

local topLayers <const> = sprite.layers
local lenTopLayers <const> = #topLayers

local keepSelection = false
local selectOnClick = false
local appPrefs <const> = app.preferences
if appPrefs then
    local timelinePrefs <const> = appPrefs.timeline
    if timelinePrefs then
        local keepSelPref <const> = timelinePrefs.keep_selection --[[@as boolean]]
        if keepSelPref then keepSelection = true end
        local selOnClkPref <const> = timelinePrefs.select_on_click --[[@as boolean]]
        if selOnClkPref then selectOnClick = true end
    end
end
local makeRange <const> = (not keepSelection)
    and selectOnClick
    and app.range.sprite == sprite

local h = lenTopLayers + 1
while h > 1 do
    h = h - 1
    local topLayer <const> = topLayers[h]
    local leaves <const> = appendLeaves(topLayer, {}, true, false, true, true)
    local lenLeaves <const> = #leaves
    local i = lenLeaves + 1
    while i > 1 do
        i = i - 1
        local leaf <const> = leaves[i]
        local cel <const> = leaf:cel(frObj)
        if cel then
            if leaf.isBackground then
                app.layer = leaf
                if makeRange then app.range.layers = { leaf } end
                return
            end

            local celPos <const> = cel.position
            local xtlCel <const> = celPos.x
            local ytlCel <const> = celPos.y
            if xMouse >= xtlCel and yMouse >= ytlCel then
                local wTile = 1
                local hTile = 1

                local isTileMap <const> = leaf.isTilemap
                local tileSet = nil
                local lenTileSet = 0

                if isTileMap then
                    tileSet = leaf.tileset
                    if tileSet then
                        local tileSize <const> = tileSet.grid.tileSize
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

                    local aLayer8 <const> = leaf.opacity or 255
                    local aCel8 <const> = cel.opacity
                    local aComp01 <const> = (aLayer8 / 255.0) * (aCel8 / 255.0)

                    local bytesStr <const> = image.bytes
                    local bpp <const> = image.bytesPerPixel

                    local isNonZero = false
                    if isTileMap then
                        local xMap <const> = xLocal // wTile
                        local yMap <const> = yLocal // hTile

                        local dataIdx <const> = (yMap * wImage + xMap) * bpp
                        local dataStr <const> = strsub(bytesStr,
                            1 + dataIdx, bpp + dataIdx)

                        local tileEntry <const> = strunpack("<I" .. bpp, dataStr)
                        local tileIndex <const> = pxTilei(tileEntry)

                        if tileIndex > 0 and tileIndex < lenTileSet then
                            -- For cases where tile sizes are unequal, aComp01
                            -- being non-zero is good enough.
                            isNonZero = aComp01 > 0.0
                            if tileSet and wTile == hTile then
                                local tile <const> = tileSet:tile(tileIndex)
                                if tile then
                                    local tileFlag <const> = pxTilef(tileEntry)
                                    local tileImage <const> = bakeFlag(
                                        tile.image, tileFlag)
                                    local xTile <const> = xLocal % tileImage.width
                                    local yTile <const> = yLocal % tileImage.height
                                    isNonZero = eval(xTile, yTile, wTile,
                                        colorMode, tileImage.bytesPerPixel,
                                        tileImage.bytes, aComp01, alphaIndex,
                                        palette)
                                end -- End tile exists.
                            end     -- End tile width and height equal.
                        end         -- End index is in range.
                    else
                        isNonZero = eval(xLocal, yLocal, wImage, colorMode, bpp,
                            bytesStr, aComp01, alphaIndex, palette)
                    end

                    if isNonZero then
                        app.layer = leaf
                        if makeRange then app.range.layers = { leaf } end
                        return
                    end -- End pixel is not transparent.
                end     -- End mouse within upper bound.
            end         -- End mouse within lower bound.
        end             -- End cel is not nil.
    end                 -- End leaves loop.
end                     -- End top layers loop.