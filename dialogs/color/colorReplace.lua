dofile("../../support/aseutilities.lua")

local targets <const> = {
    "ACTIVE",
    "ALL",
    "RANGE",
    "SELECTION",
    "TILE_SET",
    "TILE_SETS"
}

local defaults <const> = {
    target = "ACTIVE",
    includeLocked = false,
    includeHidden = false,
    tolerance = 0,
    ignoreAlpha = false,
    pullFocus = true
}

---@param a { l: number, a: number, b: number, alpha: number }
---@param b { l: number, a: number, b: number, alpha: number }
---@param alphaScale number
---@return number
local function distSqInclAlpha(a, b, alphaScale)
    -- Scale alpha to be at least somewhat
    -- proportional to other channels.
    local dt <const> = alphaScale * (b.alpha - a.alpha)
    local dl <const> = b.l - a.l
    local da <const> = b.a - a.a
    local db <const> = b.b - a.b
    return dt * dt + dl * dl + da * da + db * db
end

---@param a { l: number, a: number, b: number, alpha: number }
---@param b { l: number, a: number, b: number, alpha: number }
---@return number
local function distSqNoAlpha(a, b)
    local dl <const> = b.l - a.l
    local da <const> = b.a - a.a
    local db <const> = b.b - a.b
    return dl * dl + da * da + db * db
end

---@param cel Cel
---@param sprite Sprite
---@return Image
---@return integer
---@return integer
local function expandCelToCanvas(cel, sprite)
    local celPos <const> = cel.position
    local xSrc <const> = celPos.x
    local ySrc <const> = celPos.y

    local celImg <const> = cel.image
    local celSpec <const> = celImg.spec

    local xMin <const> = math.min(0, xSrc)
    local yMin <const> = math.min(0, ySrc)
    local xMax <const> = math.max(sprite.width - 1,
        xSrc + celSpec.width - 1)
    local yMax <const> = math.max(sprite.height - 1,
        ySrc + celSpec.height - 1)

    local wTrg <const> = 1 + xMax - xMin
    local hTrg <const> = 1 + yMax - yMin
    if wTrg < 1 or hTrg < 1 then
        return celImg, xSrc, ySrc
    end

    local trgSpec <const> = AseUtilities.createSpec(
        wTrg, hTrg, celSpec.colorMode, celSpec.colorSpace,
        celSpec.transparentColor)
    local trgImg <const> = Image(trgSpec)
    trgImg:drawImage(celImg,
        Point(xSrc - xMin, ySrc - yMin))

    return trgImg, xMin, yMin
end

---@param dialog Dialog
local function swapColors(dialog)
    local args <const> = dialog.data
    local frColor <const> = args.fromColor --[[@as Color]]
    local toColor <const> = args.toColor --[[@as Color]]
    dialog:modify {
        id = "fromColor",
        color = AseUtilities.aseColorCopy(
            toColor, "")
    }
    dialog:modify {
        id = "toColor",
        color = AseUtilities.aseColorCopy(
            frColor, "")
    }
end

local dlg <const> = Dialog { title = "Replace Color" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    onchange = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local notTileset <const> = target ~= "TILE_SET"
        local notTileSets <const> = target ~= "TILE_SETS"
        local notSel <const> = target ~= "SELECTION"
        dlg:modify { id = "includeLocked", visible = notSel and notTileSets }
        dlg:modify { id = "includeHidden", visible = notSel and notTileSets }
        dlg:modify { id = "tolerance", visible = notTileSets and notTileset }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "includeLocked",
    label = "Include:",
    text = "&Locked",
    selected = defaults.includeLocked,
    visible = defaults.target ~= "TILE_SETS"
        and defaults.target ~= "SELECTION"
}

dlg:check {
    id = "includeHidden",
    text = "&Hidden",
    selected = defaults.includeHidden,
    visible = defaults.target ~= "TILE_SETS"
        and defaults.target ~= "SELECTION"
}

dlg:newrow { always = false }

dlg:color {
    id = "fromColor",
    label = "From:",
    color = Color { r = 255, g = 255, b = 255, a = 255 }
}

dlg:newrow { always = false }

dlg:color {
    id = "toColor",
    label = "To:",
    color = Color { r = 0, g = 0, b = 0, a = 0 }
}

dlg:newrow { always = false }

dlg:slider {
    id = "tolerance",
    label = "Tolerance:",
    min = 0,
    max = 255,
    value = defaults.tolerance,
    visible = defaults.target ~= "TILE_SET"
        and defaults.target ~= "TILE_SETS",
    onchange = function()
        local args <const> = dlg.data
        local tolerance <const> = args.tolerance --[[@as integer]]
        local state <const> = tolerance > 0
        dlg:modify { id = "ignoreAlpha", visible = state }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "ignoreAlpha",
    label = "Ignore:",
    text = "&Alpha",
    selected = defaults.ignoreAlpha,
    visible = defaults.tolerance > 0
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Early returns.
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        if not activeLayer then return end
        local activeFrame <const> = site.frame
        if not activeFrame then return end

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local frColor <const> = args.fromColor --[[@as Color]]
        local toColor <const> = args.toColor --[[@as Color]]
        local tolerance <const> = args.tolerance
            or defaults.tolerance --[[@as integer]]
        local includeLocked <const> = args.includeLocked --[[@as boolean]]
        local includeHidden <const> = args.includeHidden --[[@as boolean]]
        local ignoreAlpha <const> = args.ignoreAlpha --[[@as boolean]]

        local includeTiles <const> = false
        local includeBkg <const> = toColor.alpha >= 255
        local exactSearch <const> = tolerance <= 0
        local activeSpec <const> = activeSprite.spec
        local colorMode <const> = activeSpec.colorMode

        local replaceTileSet <const> = target == "TILE_SET"
        local replaceAllTiles <const> = target == "TILE_SETS"
        if replaceTileSet or replaceAllTiles then
            ---@type Tileset[]
            local tileSets = {}

            if replaceTileSet
                and activeLayer.isTilemap
                and (includeLocked or activeLayer.isEditable)
                and (includeHidden or activeLayer.isVisible) then
                tileSets[1] = activeLayer.tileset
            end

            if replaceAllTiles then
                tileSets = activeSprite.tilesets
            end

            local frInt <const> = AseUtilities.aseColorToHex(
                frColor, colorMode)
            local toInt <const> = AseUtilities.aseColorToHex(
                toColor, colorMode)
            if frInt == toInt then return end

            local lenTileSets <const> = #tileSets
            if lenTileSets <= 0 then
                app.alert {
                    title = "Error",
                    text = "No tile sets could be found."
                }
                return
            end

            local h = 0
            while h < lenTileSets do
                h = h + 1
                local tileSet <const> = tileSets[h]
                local lenTileSet <const> = #tileSet
                local i = 0
                app.transaction("Replace Color", function()
                    while i < lenTileSet - 1 do
                        i = i + 1
                        local tile <const> = tileSet:tile(i)
                        local srcImg <const> = tile.image
                        local trgImg <const> = srcImg:clone()
                        local pxItr <const> = trgImg:pixels()
                        for pixel in pxItr do
                            if pixel() == frInt then pixel(toInt) end
                        end
                        tile.image = trgImg
                    end
                end)
            end
        else
            local trgCels <const> = AseUtilities.filterCels(
                activeSprite, activeLayer, activeFrame, target,
                includeLocked, includeHidden, includeTiles, includeBkg)
            local lenTrgCels <const> = #trgCels

            app.transaction("Replace Color", function()
                if exactSearch then
                    local frInt <const> = AseUtilities.aseColorToHex(
                        frColor, colorMode)
                    local toInt <const> = AseUtilities.aseColorToHex(
                        toColor, colorMode)
                    if frInt == toInt then return end
                    local useExpand = frInt == activeSpec.transparentColor

                    local i = 0
                    while i < lenTrgCels do
                        i = i + 1
                        local cel <const> = trgCels[i]
                        local trgImg = nil
                        if useExpand then
                            local exp <const>, xtl <const>, ytl <const> = expandCelToCanvas(
                                cel, activeSprite)
                            trgImg = exp
                            cel.position = Point(xtl, ytl)
                        else
                            trgImg = cel.image:clone()
                        end

                        local pxItr <const> = trgImg:pixels()
                        for pixel in pxItr do
                            if pixel() == frInt then pixel(toInt) end
                        end
                        cel.image = trgImg
                    end
                else
                    app.command.ChangePixelFormat { format = "rgb" }

                    local frInt <const> = AseUtilities.aseColorToHex(
                        frColor, ColorMode.RGB)
                    local toInt <const> = AseUtilities.aseColorToHex(
                        toColor, ColorMode.RGB)

                    local fromHex <const> = Clr.fromHex
                    local sRgbaToLab <const> = Clr.sRgbToSrLab2
                    local distSq = distSqInclAlpha
                    if ignoreAlpha then distSq = distSqNoAlpha end

                    local tScl <const> = 100.0
                    local tolsq <const> = tolerance * tolerance
                    local frLab <const> = sRgbaToLab(fromHex(frInt))

                    local zeroLab <const> = { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }
                    local useExpand <const> = distSq(frLab, zeroLab, tScl) <= tolsq

                    ---@type table<integer, integer>
                    local dict <const> = {}

                    local i = 0
                    while i < lenTrgCels do
                        i = i + 1
                        local cel <const> = trgCels[i]

                        local srcImg <const> = cel.image
                        local srcPxItr <const> = srcImg:pixels()
                        for srcPixel in srcPxItr do
                            local srcHex <const> = srcPixel()
                            if not dict[srcHex] then
                                local srcClr <const> = fromHex(srcHex)
                                local srcLab <const> = sRgbaToLab(srcClr)
                                if distSq(srcLab, frLab, tScl) <= tolsq then
                                    dict[srcHex] = toInt
                                else
                                    dict[srcHex] = srcHex
                                end
                            end
                        end

                        local trgImg = nil
                        if useExpand then
                            local exp <const>, xtl <const>, ytl <const> = expandCelToCanvas(
                                cel, activeSprite)
                            trgImg = exp
                            cel.position = Point(xtl, ytl)
                        else
                            trgImg = srcImg:clone()
                        end

                        local trgPxItr <const> = trgImg:pixels()
                        if ignoreAlpha then
                            for trgPixel in trgPxItr do
                                local srcHex <const> = trgPixel()
                                local srcAlpha <const> = srcHex & 0xff000000
                                local trgHex <const> = dict[srcHex]
                                local trgRgb <const> = trgHex & 0x00ffffff
                                trgPixel(srcAlpha | trgRgb)
                            end
                        else
                            for trgPixel in trgPxItr do
                                trgPixel(dict[trgPixel()])
                            end
                        end

                        cel.image = trgImg
                    end

                    AseUtilities.changePixelFormat(colorMode)
                end
            end)
        end

        -- swapColors(dlg)
        app.refresh()
    end
}

dlg:button {
    id = "swapColors",
    text = "&SWAP",
    focus = false,
    onclick = function() swapColors(dlg) end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = true,
    wait = false
}