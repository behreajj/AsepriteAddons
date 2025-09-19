dofile("../../support/aseutilities.lua")

---@param x integer
---@param y integer
---@param wImage integer
---@param colorMode ColorMode
---@param bpp integer
---@param bytesStr string
---@param aComp01 number
---@param alphaIndex integer
---@param palette Palette
---@return number
local function evalImage(
    x, y, wImage, colorMode, bpp, bytesStr,
    aComp01, alphaIndex, palette)
    local dataIdx <const> = (y * wImage + x) * bpp
    local dataStr <const> = string.sub(bytesStr,
        1 + dataIdx, bpp + dataIdx)
    local dataInt <const> = string.unpack("<I" .. bpp, dataStr)

    local a01 = 0.0
    if colorMode == ColorMode.RGB then
        local a8 <const> = (dataInt >> 0x18) & 0xff
        a01 = aComp01 * (a8 / 255.0)
    elseif colorMode == ColorMode.GRAY then
        local a8 <const> = (dataInt >> 0x08) & 0xff
        a01 = aComp01 * (a8 / 255.0)
    elseif colorMode == ColorMode.INDEXED then
        if dataInt ~= alphaIndex
            and dataInt >= 0 and dataInt < #palette then
            local aseColor <const> = palette:getColor(dataInt)
            local a8 <const> = aseColor.alpha
            a01 = aComp01 * (a8 / 255.0)
        end
    end
    return a01
end

---@param layer Layer
---@param frame Frame|integer
---@param aHier01 number
---@param xMouse integer
---@param yMouse integer
---@param colorMode ColorMode
---@param alphaIndex integer
---@param palette Palette
---@return number
---@return Layer
local function evalLayer(
    layer, frame, aHier01,
    xMouse, yMouse,
    colorMode,
    alphaIndex, palette)
    if layer.isReference then return 0.0, layer end
    if not layer.isVisible then return 0.0, layer end
    if layer.isBackground then return 1.0, layer end
    if aHier01 <= 0.0 then return 0.0, layer end

    -- print(string.format(
    --     "layerName: \"%s\"", layer.name))

    local aLayer8 <const> = layer.opacity or 255
    if aLayer8 <= 0 then return 0.0, layer end
    local aLayer01 <const> = aLayer8 / 255.0
    local aLayerHier01 <const> = aHier01 * aLayer01

    -- print(string.format(
    --     "aHier01: %.3f, aLayer01: %.3f, aLayerHier01: %.3f",
    --     aHier01, aLayer01, aLayerHier01))

    if layer.isGroup then
        local childLayers <const> = layer.layers
        if not childLayers then
            return 0.0, layer
        end

        local lenChildLayers <const> = #childLayers
        local i = lenChildLayers + 1
        while i > 1 do
            i = i - 1
            local child <const> = childLayers[i]
            local a01 <const>, candidate <const> = evalLayer(
                child, frame, aLayerHier01,
                xMouse, yMouse, colorMode, alphaIndex, palette)
            if a01 > 0.0 then return a01, candidate end
        end
    else
        local cel <const> = layer:cel(frame)
        if not cel then return 0.0, layer end

        local celPos <const> = cel.position
        local xtlCel <const> = celPos.x
        local ytlCel <const> = celPos.y

        if xMouse < xtlCel or yMouse < ytlCel then return 0.0, layer end

        local wTile = 1
        local hTile = 1

        local isTileMap <const> = layer.isTilemap
        local tileSet = nil
        local lenTileSet = 0

        if isTileMap then
            tileSet = layer.tileset
            if tileSet then
                local tileSize <const> = tileSet.grid.tileSize
                wTile = math.max(1, math.abs(tileSize.width))
                hTile = math.max(1, math.abs(tileSize.height))
                lenTileSet = #tileSet
            end -- End tileset is not nil.
        end     -- End layer is tile map.

        local image <const> = cel.image
        local specImage <const> = image.spec
        local wImage <const> = specImage.width
        local hImage <const> = specImage.height

        local xbrCel <const> = xtlCel + wImage * wTile - 1
        local ybrCel <const> = ytlCel + hImage * hTile - 1

        if xMouse > xbrCel or yMouse > ybrCel then return 0.0, layer end

        local xLocal <const> = xMouse - xtlCel
        local yLocal <const> = yMouse - ytlCel

        local aCel8 <const> = cel.opacity
        if aCel8 <= 0 then return 0.0, layer end

        local aCel01 <const> = aCel8 / 255.0
        local aFinal01 <const> = aLayerHier01 * aCel01
        local bpp <const> = image.bytesPerPixel
        local byteStr <const> = image.bytes

        if isTileMap then
            if not tileSet then return 0.0, layer end

            local xMap <const> = xLocal // wTile
            local yMap <const> = yLocal // hTile

            local dataIdx <const> = (yMap * wImage + xMap) * bpp
            local dataStr <const> = string.sub(byteStr,
                1 + dataIdx, bpp + dataIdx)

            local tileEntry <const> = string.unpack("<I" .. bpp, dataStr)
            local tileIndex <const> = app.pixelColor.tileI(tileEntry)

            if tileIndex <= 0 or tileIndex >= lenTileSet then
                return 0.0, layer
            end

            local tile <const> = tileSet:tile(tileIndex)
            if not tile then return 0.0, layer end

            if wTile ~= hTile then return aFinal01, layer end

            local tileFlag <const> = app.pixelColor.tileF(tileEntry)
            local tileImage <const> = AseUtilities.bakeFlag(
                tile.image, tileFlag)
            local xTile <const> = xLocal % tileImage.width
            local yTile <const> = yLocal % tileImage.height

            local a01 <const> = evalImage(xTile, yTile, wTile,
                colorMode, tileImage.bytesPerPixel,
                tileImage.bytes, aFinal01, alphaIndex,
                palette)
            return a01, layer
        end -- End tile map special case.

        local a01 <const> = evalImage(xLocal, yLocal,
            wImage, colorMode, bpp, byteStr, aFinal01,
            alphaIndex, palette)
        return a01, layer
    end -- End group or leaf check.

    return 0.0, layer
end

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local frObj <const> = site.frame
if not frObj then return end

local xMouse <const>, yMouse <const> = AseUtilities.getMouse()

if xMouse < 0 or yMouse < 0 then return end

local specSprite <const> = sprite.spec
local wSprite <const> = specSprite.width
local hSprite <const> = specSprite.height
local colorMode <const> = specSprite.colorMode
local alphaIndex <const> = specSprite.transparentColor

if xMouse >= wSprite or yMouse >= hSprite then return end

local topLayers <const> = sprite.layers
local lenTopLayers <const> = #topLayers

local palette <const> = AseUtilities.getPalette(frObj, sprite.palettes)

local keepSelection = false
local selectOnClick = false
local appPrefs <const> = app.preferences
if appPrefs then
    local tlPrefs <const> = appPrefs.timeline
    if tlPrefs then
        local keepSelPref <const> = tlPrefs.keep_selection --[[@as boolean]]
        if keepSelPref then keepSelection = true end
        local selOnClkPref <const> = tlPrefs.select_on_click --[[@as boolean]]
        if selOnClkPref then selectOnClick = true end
    end
end
local makeRange <const> = (not keepSelection)
    and selectOnClick
    and app.range.sprite == sprite

local chosenLayer = nil
local h = lenTopLayers + 1
while h > 1 and chosenLayer == nil do
    h = h - 1
    local a01 <const>, candidate <const> = evalLayer(
        topLayers[h], frObj, 1.0,
        xMouse, yMouse, colorMode, alphaIndex, palette)

    -- print(string.format(
    --     "a01: %.3f, candidate: \"%s\"",
    --     a01, candidate.name))

    if a01 > 0.0 then
        chosenLayer = candidate
    end
end -- End top layers loop.

if chosenLayer then
    app.layer = chosenLayer
    if makeRange then app.range.layers = { chosenLayer } end
end