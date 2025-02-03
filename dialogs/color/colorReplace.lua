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
    switchColors = false,
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
        Point(xSrc - xMin, ySrc - yMin), 255, BlendMode.SRC)

    return trgImg, xMin, yMin
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
        local tolerance <const> = args.tolerance --[[@as integer]]

        local notTileset <const> = target ~= "TILE_SET"
        local notTileSets <const> = target ~= "TILE_SETS"
        local notSel <const> = target ~= "SELECTION"

        dlg:modify { id = "includeLocked", visible = notSel and notTileSets }
        dlg:modify { id = "includeHidden", visible = notSel and notTileSets }
        dlg:modify { id = "tolerance", visible = notTileSets and notTileset }
        dlg:modify { id = "ignoreAlpha", visible = notTileSets and notTileset
            and tolerance > 0 }
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
        local target <const> = args.target --[[@as string]]
        local tolerance <const> = args.tolerance --[[@as integer]]

        local tolGtZero <const> = tolerance > 0
        local noTiles <const> = target ~= "TILE_SET" and target ~= "TILE_SETS"

        dlg:modify { id = "ignoreAlpha", visible = noTiles and tolGtZero }
        dlg:modify { id = "switchColors", visible = (not tolGtZero) }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "ignoreAlpha",
    label = "Ignore:",
    text = "&Alpha",
    selected = defaults.ignoreAlpha,
    visible = defaults.target ~= "TILE_SET"
        and defaults.target ~= "TILE_SETS"
        and defaults.tolerance > 0
}

dlg:newrow { always = false }

dlg:check {
    id = "switchColors",
    label = "Swap:",
    text = "Colo&rs",
    selected = defaults.switchColors,
    visible = defaults.tolerance <= 0
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
        local switchColors <const> = args.switchColors --[[@as boolean]]
        local ignoreAlpha <const> = args.ignoreAlpha --[[@as boolean]]

        -- Cache methods used in all versions of replace.
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local tconcat <const> = table.concat
        local createSpec <const> = AseUtilities.createSpec

        -- Unpack sprite spec.
        local activeSpec <const> = activeSprite.spec
        local colorMode <const> = activeSpec.colorMode
        local colorSpace <const> = activeSpec.colorSpace
        local alphaIndex <const> = activeSpec.transparentColor

        -- Verify boolean conditions.
        local includeBkg <const> = toColor.alpha >= 255
        local tIgnoreVerif <const> = ignoreAlpha and frColor.alpha > 0
        local exactSearch <const> = tolerance <= 0
        local switchVerif <const> = exactSearch and switchColors

        local frInt <const> = AseUtilities.aseColorToHex(
            frColor, colorMode)
        local toInt <const> = AseUtilities.aseColorToHex(
            toColor, colorMode)

        -- Indices may exceed a byte and throw an error when packed.
        if colorMode == ColorMode.INDEXED
            and (frInt < 0 or frInt > 255 or toInt < 0 or toInt > 255) then
            return
        end

        local replaceTileSet <const> = target == "TILE_SET"
        local replaceAllTiles <const> = target == "TILE_SETS"
        if frInt == toInt
            and (exactSearch
                or (replaceTileSet or replaceAllTiles)) then
            return
        end

        local srcBpp = 1
        if colorMode == ColorMode.RGB then
            srcBpp = 4
        elseif colorMode == ColorMode.GRAY then
            srcBpp = 2
        end
        local bppFormatStr <const> = "<I" .. srcBpp

        local frStr <const> = strpack(bppFormatStr, frInt)
        local toStr <const> = strpack(bppFormatStr, toInt)

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

            local lenTileSets <const> = #tileSets
            if lenTileSets <= 0 then
                app.alert {
                    title = "Error",
                    text = "No tile sets could be found."
                }
                return
            end

            local max <const> = math.max
            local abs <const> = math.abs

            local h = 0
            while h < lenTileSets do
                h = h + 1
                local tileSet <const> = tileSets[h]
                local lenTileSet <const> = #tileSet

                local tileSize <const> = tileSet.grid.tileSize
                local wSrc <const> = max(1, abs(tileSize.width))
                local hSrc <const> = max(1, abs(tileSize.height))
                local lenSrc = wSrc * hSrc

                app.transaction("Replace Color Tiles", function()
                    local i = 0
                    while i < lenTileSet - 1 do
                        i = i + 1
                        local tile <const> = tileSet:tile(i)
                        if tile then
                            local tileBytes <const> = tile.image.bytes

                            ---@type string[]
                            local trgByteStrs <const> = {}
                            local j = 0
                            while j < lenSrc do
                                local jbpp <const> = j * srcBpp
                                local tileHexStr <const> = strsub(
                                    tileBytes, 1 + jbpp, srcBpp + jbpp)

                                local trgHexStr = tileHexStr
                                if tileHexStr == frStr then
                                    trgHexStr = toStr
                                elseif switchVerif and tileHexStr == toStr then
                                    trgHexStr = frStr
                                end

                                j = j + 1
                                trgByteStrs[j] = trgHexStr
                            end

                            local trgSpec <const> = createSpec(wSrc, hSrc,
                                colorMode, colorSpace, alphaIndex)
                            local trgImg <const> = Image(trgSpec)
                            trgImg.bytes = tconcat(trgByteStrs)
                            tile.image = trgImg
                        end -- End tile exists check.
                    end     -- End tile in tile set loop.
                end)        -- End transaction.
            end             -- End all tile sets loop.
        else
            if (not exactSearch) and colorMode ~= ColorMode.RGB then
                app.alert {
                    title = "Error",
                    text = "Only RGB color mode is supported."
                }
                return
            end

            local trgFrames <const> = Utilities.flatArr2(
                AseUtilities.getFrames(
                    activeSprite, target ~= "SELECTION"
                    and target or "ALL"))
            local trgCels <const> = AseUtilities.filterCels(
                activeSprite, activeLayer, trgFrames, target,
                includeLocked, includeHidden, false, includeBkg)
            local lenTrgCels <const> = #trgCels

            if exactSearch then
                local useExpand <const> = (frInt == alphaIndex)
                    or (switchColors and (toInt == alphaIndex))

                app.transaction("Replace Color Exact", function()
                    local i = 0
                    while i < lenTrgCels do
                        i = i + 1
                        local cel <const> = trgCels[i]
                        local srcImg = cel.image
                        if useExpand then
                            local exp <const>,
                            xtl <const>,
                            ytl <const> = expandCelToCanvas(cel, activeSprite)
                            srcImg = exp
                            cel.position = Point(xtl, ytl)
                        end

                        local srcBytes <const> = srcImg.bytes
                        local srcSpec <const> = srcImg.spec
                        local wSrc <const> = srcSpec.width
                        local hSrc <const> = srcSpec.height
                        local lenSrc <const> = wSrc * hSrc

                        ---@type string[]
                        local trgByteStrs <const> = {}
                        local j = 0
                        while j < lenSrc do
                            local jbpp <const> = j * srcBpp
                            local srcHexStr <const> = strsub(
                                srcBytes, 1 + jbpp, srcBpp + jbpp)

                            local trgHexStr = srcHexStr
                            if srcHexStr == frStr then
                                trgHexStr = toStr
                            elseif switchVerif and srcHexStr == toStr then
                                trgHexStr = frStr
                            end

                            j = j + 1
                            trgByteStrs[j] = trgHexStr
                        end

                        local trgSpec <const> = createSpec(wSrc, hSrc,
                            colorMode, colorSpace, alphaIndex)
                        local trgImg <const> = Image(trgSpec)
                        trgImg.bytes = tconcat(trgByteStrs)
                        cel.image = trgImg
                    end -- End of cels loop.
                end)    -- End exact transaction.
            else
                -- Fuzzy tolerance search.
                local fromHex <const> = Clr.fromHexAbgr32
                local sRgbaToLab <const> = Clr.sRgbToSrLab2
                local strunpack <const> = string.unpack
                local distSq <const> = tIgnoreVerif
                    and distSqNoAlpha
                    or distSqInclAlpha

                local tScl <const> = 100.0
                local tolsq <const> = tolerance * tolerance
                local frLab <const> = sRgbaToLab(fromHex(frInt))

                local zeroLab <const> = { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }
                local useExpand <const> = distSq(frLab, zeroLab, tScl) <= tolsq

                ---@type table<integer, integer>
                local dict <const> = {}

                app.transaction("Replace Color Fuzzy", function()
                    local i = 0
                    while i < lenTrgCels do
                        i = i + 1
                        local cel <const> = trgCels[i]
                        local srcImg = cel.image
                        if useExpand then
                            local exp <const>,
                            xtl <const>,
                            ytl <const> = expandCelToCanvas(cel, activeSprite)
                            srcImg = exp
                            cel.position = Point(xtl, ytl)
                        end

                        local srcBytes <const> = srcImg.bytes
                        local srcSpec <const> = srcImg.spec
                        local wSrc <const> = srcSpec.width
                        local hSrc <const> = srcSpec.height
                        local lenSrc <const> = wSrc * hSrc

                        ---@type string[]
                        local trgByteStrs <const> = {}
                        local j = 0
                        while j < lenSrc do
                            local jbpp <const> = j * srcBpp
                            local srcHexStr <const> = strsub(
                                srcBytes, 1 + jbpp, srcBpp + jbpp)
                            local srcHexInt <const> = strunpack(
                                bppFormatStr, srcHexStr)

                            local trgHexInt = srcHexInt
                            if dict[srcHexInt] then
                                trgHexInt = dict[srcHexInt]
                            else
                                local srcClr <const> = fromHex(srcHexInt)
                                local srcLab <const> = sRgbaToLab(srcClr)
                                if distSq(srcLab, frLab, tScl) <= tolsq then
                                    trgHexInt = toInt
                                end
                                dict[srcHexInt] = trgHexInt
                            end

                            j = j + 1
                            if tIgnoreVerif then
                                trgByteStrs[j] = strpack("I4",
                                    (srcHexInt & 0xff000000)
                                    | (trgHexInt & 0x00ffffff))
                            else
                                trgByteStrs[j] = strpack("I4", trgHexInt)
                            end
                        end

                        local trgSpec <const> = createSpec(wSrc, hSrc,
                            colorMode, colorSpace, alphaIndex)
                        local trgImg <const> = Image(trgSpec)
                        trgImg.bytes = tconcat(trgByteStrs)
                        cel.image = trgImg
                    end -- End of cels loop.
                end)    -- End fuzzy transaction.
            end         -- End of exact vs. tolerance.
        end             -- End of tiles vs. canvas.

        app.refresh()
    end
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