dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")

local palTypes <const> = { "ACTIVE", "FILE" }
local colorSpaces <const> = {
    "LINEAR_RGB",
    "S_RGB",
    "SR_LAB_2"
}

local targets <const> = { "ACTIVE", "ALL", "RANGE" }

local defaults <const> = {
    target = "ACTIVE",
    palType = "ACTIVE",
    cvgLabRad = 175,
    cvgNormRad = 120,
    octCapacityBits = 4,
    minCapacityBits = 2,
    maxCapacityBits = 16,
    printElapsed = false,
    clrSpacePreset = "LINEAR_RGB",
    pullFocus = false
}

---@param preset string
---@return Bounds3
local function boundsFromPreset(preset)
    if preset == "CIE_LAB"
        or preset == "SR_LAB_2" then
        return Bounds3.lab()
    else
        return Bounds3.unitCubeUnsigned()
    end
end

---@param clr Clr
---@return Vec3
local function clrToVec3lRgb(clr)
    local lin <const> = Clr.sRgbTolRgbInternal(clr)
    return Vec3.new(lin.r, lin.g, lin.b)
end

---@param clr Clr
---@return Vec3
local function clrToVec3sRgb(clr)
    return Vec3.new(clr.r, clr.g, clr.b)
end

---@param clr Clr
---@return Vec3
local function clrToVec3SrLab2(clr)
    local lab <const> = Clr.sRgbToSrLab2(clr)
    return Vec3.new(lab.a, lab.b, lab.l)
end

---@param preset string
---@return fun(clr: Clr): Vec3
local function clrToV3FuncFromPreset(preset)
    if preset == "LINEAR_RGB" then
        return clrToVec3lRgb
    elseif preset == "SR_LAB_2" then
        return clrToVec3SrLab2
    else
        return clrToVec3sRgb
    end
end

local dlg <const> = Dialog { title = "Palette To Cel" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.palType,
    options = palTypes,
    onchange = function()
        local args <const> = dlg.data
        local palType <const> = args.palType --[[@as string]]
        dlg:modify {
            id = "palFile",
            visible = palType == "FILE"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "aseprite", "gpl", "pal", "png", "webp" },
    open = true,
    visible = defaults.palType == "FILE"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "clrSpacePreset",
    label = "Color Space:",
    option = defaults.clrSpacePreset,
    options = colorSpaces,
    onchange = function()
        local args <const> = dlg.data
        local preset <const> = args.clrSpacePreset --[[@as string]]
        local isLab <const> = preset == "CIE_LAB"
            or preset == "SR_LAB_2"
        dlg:modify {
            id = "cvgLabRad",
            visible = isLab
        }
        dlg:modify {
            id = "cvgNormRad",
            visible = not isLab
        }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "cvgLabRad",
    label = "Radius:",
    min = 25,
    max = 242,
    value = defaults.cvgLabRad,
    visible = defaults.clrSpacePreset == "CIE_LAB"
        or defaults.clrSpacePreset == "SR_LAB_2"
}

dlg:newrow { always = false }

dlg:slider {
    id = "cvgNormRad",
    label = "Radius:",
    min = 5,
    max = 174,
    value = defaults.cvgNormRad,
    visible = defaults.clrSpacePreset ~= "CIE_LAB"
        and defaults.clrSpacePreset ~= "SR_LAB_2"
}

dlg:newrow { always = false }

dlg:slider {
    id = "octCapacity",
    label = "Capacity (2^n):",
    min = defaults.minCapacityBits,
    max = defaults.maxCapacityBits,
    value = defaults.octCapacityBits,
    visible = defaults.clampTo256
}

dlg:newrow { always = false }

dlg:check {
    id = "printElapsed",
    label = "Print:",
    text = "Diagnostic",
    selected = defaults.printElapsed
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Begin timing the function elapsed.
        local args <const> = dlg.data
        local printElapsed <const> = args.printElapsed --[[@as boolean]]
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then
            startTime = os.clock()
        end

        -- Early returns.
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local srcLayer <const> = site.layer
        if not srcLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        if srcLayer.isGroup then
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        if srcLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        -- Check for tile maps.
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
        end

        -- Change color mode.
        local oldMode <const> = activeSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        -- Cache global methods.
        local fromHex <const> = Clr.fromHex
        local v3Hash <const> = Vec3.hashCode
        local octInsert <const> = Octree.insert
        local search <const> = Octree.queryInternal
        local tilesToImage <const> = AseUtilities.tilesToImage
        local strfmt <const> = string.format
        local transact <const> = app.transaction

        -- Convert source palette colors to points
        -- inserted into octree.
        local palType <const> = args.palType
            or defaults.palType --[[@as string]]
        local palFile <const> = args.palFile --[[@as string]]
        local hexesProfile <const>, hexesSrgb <const> = AseUtilities.asePaletteLoad(
            palType, palFile, 0, 256, true)

        -- Select which conversion functions to use.
        local clrSpacePreset <const> = args.clrSpacePreset
            or defaults.clrSpacePreset --[[@as string]]
        local octBounds <const> = boundsFromPreset(clrSpacePreset)
        local clrV3Func <const> = clrToV3FuncFromPreset(clrSpacePreset)

        -- Select query radius according to color space.
        local cvgRad = 0.0
        local distFunc = Vec3.distEuclidean
        if clrSpacePreset == "CIE_LAB"
            or clrSpacePreset == "SR_LAB_2" then
            cvgRad = args.cvgLabRad
                or defaults.cvgLabRad --[[@as number]]

            -- See https://www.wikiwand.com/en/
            -- Color_difference#/Other_geometric_constructions
            distFunc = function(a, b)
                local da <const> = b.x - a.x
                local db <const> = b.y - a.y
                return math.sqrt(da * da + db * db)
                    + math.abs(b.z - a.z)
            end
        else
            cvgRad = args.cvgNormRad
                or defaults.cvgNormRad --[[@as number]]
            cvgRad = cvgRad * 0.01
        end

        -- Create octree.
        -- local exactMatches = {}
        ---@type table<integer, integer>
        local ptToHexDict <const> = {}
        local hexesSrgbLen <const> = #hexesSrgb
        local octExpBits <const> = args.octCapacity
            or defaults.octCapacityBits --[[@as integer]]
        local octCapacity = 1 << octExpBits
        local octree <const> = Octree.new(octBounds, octCapacity, 1)

        local hexIdx = 0
        while hexIdx < hexesSrgbLen do
            hexIdx = hexIdx + 1
            local hexSrgb <const> = hexesSrgb[hexIdx]
            if (hexSrgb & 0xff000000) ~= 0 then
                local clr <const> = fromHex(hexSrgb)
                local pt <const> = clrV3Func(clr)
                local hexProfile <const> = hexesProfile[hexIdx]
                -- exactMatches[hexProfile] = true
                ptToHexDict[v3Hash(pt)] = hexProfile
                octInsert(octree, pt)
            end
        end

        Octree.cull(octree)

        -- Get frames.
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Create a new layer, srcLayer should not be a group,
        -- and thus have an opacity and blend mode.
        local trgLayer = nil
        app.transaction("New Layer", function()
            trgLayer = activeSprite:newLayer()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = string.format("%s.%s.%03d",
                srcLayerName, clrSpacePreset, hexesSrgbLen)
            trgLayer.parent = srcLayer.parent
            trgLayer.opacity = srcLayer.opacity
            trgLayer.blendMode = srcLayer.blendMode
        end)

        local rgbColorMode <const> = ColorMode.RGB
        local lenFrames <const> = #frames
        local i = 0
        while i < lenFrames do
            i = i + 1
            local srcFrame <const> = frames[i]
            local srcCel <const> = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, rgbColorMode)
                end

                -- Get unique hexadecimal values from image.
                -- There's no need to preserve order.
                ---@type table<integer, boolean>
                local hexesUnique <const> = {}
                local srcPxItr <const> = srcImg:pixels()
                for pixel in srcPxItr do
                    hexesUnique[pixel()] = true
                end

                -- Create a table where unique hexes are associated
                -- with Vec3 queries to an octree.
                ---@type {hex: integer, point: Vec3}[]
                local queries <const> = {}
                local lenQueries = 0
                for k, _ in pairs(hexesUnique) do
                    local clr <const> = fromHex(k)
                    local pt <const> = clrV3Func(clr)
                    lenQueries = lenQueries + 1
                    queries[lenQueries] = { hex = k, point = pt }
                end

                -- Find nearest color in palette.
                ---@type table<integer, integer>
                local correspDict <const> = {}
                local j = 0
                while j < lenQueries do
                    j = j + 1
                    local query <const> = queries[j]
                    local queryHex <const> = query.hex
                    local resultHex = 0x0
                    -- if exactMatches[queryHex] then
                    -- resultHex = queryHex
                    -- else
                    local nearPoint <const>, _ <const> = search(
                        octree, query.point, cvgRad, distFunc)
                    if nearPoint then
                        local hsh <const> = v3Hash(nearPoint)
                        resultHex = ptToHexDict[hsh]
                    end
                    -- end
                    correspDict[queryHex] = resultHex & 0x00ffffff
                end

                -- Apply colors to image.
                -- Use source color alpha.
                local trgImg <const> = srcImg:clone()
                local trgPxItr <const> = trgImg:pixels()
                for pixel in trgPxItr do
                    local srcHex <const> = pixel()
                    pixel(srcHex & 0xff000000 | correspDict[srcHex])
                end

                transact(
                    strfmt("PaletteToCel %d", srcFrame),
                    function()
                        local trgCel <const> = activeSprite:newCel(
                            trgLayer, srcFrame,
                            trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    end)
            end
        end

        AseUtilities.changePixelFormat(oldMode)
        app.refresh()

        if printElapsed then
            endTime = os.clock()
            elapsed = endTime - startTime
            app.alert {
                title = "Diagnostic",
                text = {
                    string.format("Start: %.2f", startTime),
                    string.format("End: %.2f", endTime),
                    string.format("Elapsed: %.6f", elapsed),
                    string.format("Colors: %d", hexesSrgbLen),
                }
            }
        end
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