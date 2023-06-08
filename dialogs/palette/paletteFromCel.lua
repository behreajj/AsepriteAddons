dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")

local colorSpaces = {
    "LINEAR_RGB",
    "S_RGB",
    "SR_LAB_2"
}

local defaults = {
    removeAlpha = true,
    clampTo256 = true,
    printElapsed = false,
    octThreshold = 255,
    minThreshold = 8,
    maxThreshold = 512,
    octCapacityBits = 9,
    minCapacityBits = 2,
    maxCapacityBits = 15,
    showRefineAt = 2,
    refineCapacity = 0,
    minRefine = -256,
    maxRefine = 256,
    prependMask = true,
    target = "ACTIVE",
    paletteIndex = 1,
    clrSpacePreset = "LINEAR_RGB",
    pullFocus = false
}

local function sortByPreset(preset, arr)
    if preset == "CIE_XYZ" then
        -- Y corresponds to perceived brightness.
        table.sort(arr, function(a, b) return a.y < b.y end)
    elseif preset == "LINEAR_RGB"
        or preset == "S_RGB" then
        -- Average brightness is good enough.
        table.sort(arr, function(a, b)
            return ((a.x + a.y + a.z) / 3.0)
                < ((b.x + b.y + b.z) / 3.0)
        end)
    else
        -- In CIE LAB, L is assigned to z. Default
        -- Vec3 comparator prioritizes the last
        -- component (z).
        table.sort(arr)
    end
end

local function boundsFromPreset(preset)
    if preset == "CIE_LAB"
        or preset == "SR_LAB_2" then
        return Bounds3.lab()
    else
        return Bounds3.unitCubeUnsigned()
    end
end

local function clrToVec3lRgb(clr)
    local lin = Clr.sRgbTolRgbInternal(clr)
    return Vec3.new(lin.r, lin.g, lin.b)
end

local function clrToVec3sRgb(clr)
    return Vec3.new(clr.r, clr.g, clr.b)
end

local function clrToVec3SrLab2(clr)
    local lab = Clr.sRgbToSrLab2(clr)
    return Vec3.new(lab.a, lab.b, lab.l)
end

local function clrToV3FuncFromPreset(preset)
    if preset == "LINEAR_RGB" then
        return clrToVec3lRgb
    elseif preset == "SR_LAB_2" then
        return clrToVec3SrLab2
    else
        return clrToVec3sRgb
    end
end

local function vec3ToClrlRgb(v3)
    local lin = Clr.new(v3.x, v3.y, v3.z, 1.0)
    return Clr.lRgbTosRgbInternal(lin)
end

local function vec3ToClrsRgb(v3)
    return Clr.new(v3.x, v3.y, v3.z, 1.0)
end

local function vec3ToClrSrLab2(v3)
    return Clr.srLab2TosRgb(v3.z, v3.x, v3.y, 1.0)
end

local function v3ToClrFuncFromPreset(preset)
    if preset == "LINEAR_RGB" then
        return vec3ToClrlRgb
    elseif preset == "SR_LAB_2" then
        return vec3ToClrSrLab2
    else
        return vec3ToClrsRgb
    end
end

local dlg = Dialog { title = "Palette From Cel" }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = defaults.prependMask,
}

dlg:newrow { always = false }

dlg:check {
    id = "removeAlpha",
    label = "Opaque Colors:",
    selected = defaults.removeAlpha,
    onclick = function()
        local args = dlg.data
        local state = args.clampTo256
        local removeAlpha = args.removeAlpha
        dlg:modify {
            id = "alphaWarn",
            visible = state and (not removeAlpha)
        }
        dlg:modify {
            id = "alphaWarn",
            text = string.format(
                "Opaque if over %d.",
                args.octThreshold)
        }
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "alphaWarn",
    label = "Note:",
    text = "Opaque if over threshold.",
    visible = defaults.clampTo256
        and (not defaults.removeAlpha)
}

dlg:newrow { always = false }

dlg:check {
    id = "clampTo256",
    label = "Octree:",
    text = "At Threshold",
    selected = defaults.clampTo256,
    onclick = function()
        local args = dlg.data
        local clamp = args.clampTo256
        local removeAlpha = args.removeAlpha
        local octCap = args.octCapacity
        dlg:modify { id = "octThreshold", visible = clamp }
        dlg:modify { id = "octCapacity", visible = clamp }
        dlg:modify { id = "refineCapacity", visible = clamp and (octCap > 8) }
        dlg:modify { id = "clrSpacePreset", visible = clamp }
        dlg:modify { id = "printElapsed", visible = clamp }
        dlg:modify {
            id = "alphaWarn",
            visible = clamp and (not removeAlpha)
        }
        dlg:modify {
            id = "alphaWarn",
            text = string.format(
                "Opaque if over %d.",
                args.octThreshold)
        }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "octThreshold",
    label = "Threshold:",
    min = defaults.minThreshold,
    max = defaults.maxThreshold,
    value = defaults.octThreshold,
    visible = defaults.clampTo256,
    onchange = function()
        local args = dlg.data
        dlg:modify {
            id = "alphaWarn",
            text = string.format(
                "Opaque if over %d.",
                args.octThreshold)
        }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "octCapacity",
    label = "Capacity (2^n):",
    min = defaults.minCapacityBits,
    max = defaults.maxCapacityBits,
    value = defaults.octCapacityBits,
    visible = defaults.clampTo256,
    onchange = function()
        local args = dlg.data
        local octCap = args.octCapacity
        dlg:modify {
            id = "refineCapacity",
            visible = (octCap >= defaults.showRefineAt)
        }

        local r = (1 << octCap) // 2
        dlg:modify { id = "refineCapacity", min = -r }
        dlg:modify { id = "refineCapacity", max = r }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "refineCapacity",
    label = "Refine:",
    min = defaults.minRefine,
    max = defaults.maxRefine,
    value = defaults.refineCapacity,
    visible = defaults.clampTo256
        and (defaults.octCapacityBits
            >= defaults.showRefineAt)
}

dlg:newrow { always = false }

dlg:combobox {
    id = "clrSpacePreset",
    label = "Color Space:",
    option = defaults.clrSpacePreset,
    options = colorSpaces,
    visible = defaults.clampTo256
}

dlg:newrow { always = false }

dlg:check {
    id = "printElapsed",
    label = "Print:",
    text = "Diagnostic",
    selected = defaults.printElapsed,
    visible = defaults.clampTo256
}

dlg:newrow { always = false }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = { "ACTIVE", "SAVE" },
    onchange = function()
        local md = dlg.data.target
        dlg:modify {
            id = "paletteIndex",
            visible = md == "ACTIVE"
        }
        dlg:modify {
            id = "filepath",
            visible = md == "SAVE"
        }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "paletteIndex",
    label = "Palette:",
    min = 1,
    max = 96,
    value = defaults.paletteIndex,
    visible = defaults.target == "ACTIVE"
}

dlg:newrow { always = false }

dlg:file {
    id = "filepath",
    filetypes = { "aseprite", "gpl", "pal", "png", "webp" },
    save = true,
    visible = defaults.target == "SAVE"
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Begin measuring elapsed time.
        local args = dlg.data
        local printElapsed = args.printElapsed --[[@as boolean]]
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then startTime = os.clock() end

        -- Early returns.
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local srcFrame = site.frame
        if not srcFrame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        local srcLayer = site.layer
        if not srcLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
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

        -- Unpack arguments.
        local target = args.target
            or defaults.target --[[@as string]]
        local ocThreshold = args.octThreshold
            or defaults.octThreshold --[[@as integer]]
        local clampTo256 = args.clampTo256 --[[@as boolean]]
        local prependMask = args.prependMask --[[@as boolean]]
        local removeAlpha = args.removeAlpha --[[@as boolean]]
        local octCapBits = args.octCapacity
            or defaults.octCapacityBits --[[@as integer]]
        local refineCap = args.refineCapacity
            or defaults.refineCapacity --[[@as integer]]

        local srcImg = nil
        local spriteSpec = activeSprite.spec
        local spriteColorMode = spriteSpec.colorMode
        if srcLayer.isGroup then
            local groupRect = nil
            srcImg, groupRect = AseUtilities.flattenGroup(
                srcLayer, srcFrame,
                spriteColorMode,
                spriteSpec.colorSpace,
                spriteSpec.transparentColor,
                true, true, true, true)
        else
            local srcCel = srcLayer:cel(srcFrame)
            if not srcCel then
                app.alert {
                    title = "Error",
                    text = "There is no active cel."
                }
                return
            end
            srcImg = srcCel.image
            if srcLayer.isTilemap then
                srcImg = AseUtilities.tilesToImage(
                    srcImg, srcLayer.tileset, spriteColorMode)
            end
        end

        -- Determine alpha mask according to color mode.
        local alphaMask = 0
        if removeAlpha then
            if spriteColorMode == ColorMode.GRAY then
                alphaMask = 0xff00
            else
                alphaMask = 0xff000000
            end
        end

        ---@type table<integer, integer>
        local dictionary = {}
        local idx = 0
        local pxItr = srcImg:pixels()

        if spriteColorMode == ColorMode.RGB then
            for pixel in pxItr do
                local hex = pixel()
                if ((hex >> 0x18) & 0xff) > 0 then
                    hex = alphaMask | hex
                    if not dictionary[hex] then
                        idx = idx + 1
                        dictionary[hex] = idx
                    end
                end
            end
        elseif spriteColorMode == ColorMode.INDEXED then
            local srcPal = AseUtilities.getPalette(
                srcFrame, activeSprite.palettes)
            local aseToHex = AseUtilities.aseColorToHex
            local rgbColorMode = ColorMode.RGB
            local srcPalLen = #srcPal
            for pixel in pxItr do
                local srcIndex = pixel()
                if srcIndex > -1 and srcIndex < srcPalLen then
                    local aseColor = srcPal:getColor(srcIndex)
                    if aseColor.alpha > 0 then
                        local hex = aseToHex(aseColor, rgbColorMode)
                        hex = alphaMask | hex
                        if not dictionary[hex] then
                            idx = idx + 1
                            dictionary[hex] = idx
                        end
                    end
                end
            end
        elseif spriteColorMode == ColorMode.GRAY then
            for pixel in pxItr do
                local hexGray = pixel()
                if ((hexGray >> 0x08) & 0xff) > 0 then
                    hexGray = alphaMask | hexGray
                    local a = (hexGray >> 0x08) & 0xff
                    local v = hexGray & 0xff
                    local hex = a << 0x18 | v << 0x10 | v << 0x08 | v
                    if not dictionary[hex] then
                        idx = idx + 1
                        dictionary[hex] = idx
                    end
                end
            end
        end

        -- Convert dictionary to set.
        local hexes = {}
        for k, v in pairs(dictionary) do
            hexes[v] = k
        end

        -- The oldHexesLen and centersLen need to be
        -- set here for print diagnostic purposes.
        local oldLenHexes = #hexes
        local lenCenters = 0
        local octCapacity = refineCap + (1 << octCapBits)
        local lenHexes = oldLenHexes
        if clampTo256 and lenHexes > ocThreshold then
            local clrSpacePreset = args.clrSpacePreset
                or defaults.clrSpacePreset --[[@as string]]

            local fromHex = Clr.fromHex
            local toHex = Clr.toHex
            local octins = Octree.insert
            local clrV3Func = clrToV3FuncFromPreset(clrSpacePreset)
            local v3ClrFunc = v3ToClrFuncFromPreset(clrSpacePreset)
            local bounds = boundsFromPreset(clrSpacePreset)

            -- Subdivide once so that there are at least 8 colors
            -- returned in cases where an input palette count
            -- is barely over threshold, e.g., 380 over 255.
            local octree = Octree.new(bounds, octCapacity, 1)
            Octree.subdivide(octree, 1, octCapacity)

            -- This shouldn't need to check for transparent
            -- colors, as they would've been filtered above.
            local i = 0
            while i < lenHexes do
                i = i + 1
                local clr = fromHex(hexes[i])
                octins(octree, clrV3Func(clr))
            end

            Octree.cull(octree)

            local centers = Octree.centersMean(octree, {})
            sortByPreset(clrSpacePreset, centers)

            lenCenters = #centers
            local centerHexes = {}
            local j = 0
            while j < lenCenters do
                j = j + 1
                local srgb = v3ClrFunc(centers[j])
                centerHexes[j] = toHex(srgb)
            end

            hexes = centerHexes
            lenHexes = #hexes
        end

        if prependMask then
            Utilities.prependMask(hexes)
        end

        if target == "SAVE" then
            local filepath = args.filepath --[[@as string]]
            local palette = Palette(lenHexes)
            local k = 0
            while k < lenHexes do
                k = k + 1
                -- This does not create transactions.
                palette:setColor(k - 1,
                    AseUtilities.hexToAseColor(hexes[k]))
            end
            palette:saveAs(filepath)
            app.alert { title = "Success", text = "Palette saved." }
        else
            -- How to handle out of bounds palette index?
            local palIdx = args.paletteIndex
                or defaults.paletteIndex --[[@as integer]]
            if palIdx > #activeSprite.palettes then
                app.alert {
                    title = "Error",
                    text = "Palette index is out of bounds."
                }
                return
            end

            if spriteColorMode == ColorMode.INDEXED then
                app.command.ChangePixelFormat { format = "rgb" }
                AseUtilities.setPalette(hexes, activeSprite, palIdx)
                app.command.ChangePixelFormat { format = "indexed" }
            else
                AseUtilities.setPalette(hexes, activeSprite, palIdx)
            end
        end

        if printElapsed then
            endTime = os.clock()
            elapsed = endTime - startTime

            local txtArr = {
                string.format("Start: %.2f", startTime),
                string.format("End: %.2f", endTime),
                string.format("Elapsed: %.6f", elapsed),
                string.format("Raw Colors: %d", oldLenHexes)
            }

            if clampTo256 and lenCenters > 0 then
                table.insert(txtArr,
                    string.format("Capacity: %d", octCapacity))
                table.insert(txtArr,
                    string.format("Octree Colors: %d", lenCenters))
            end

            app.alert { title = "Diagnostic", text = txtArr }
        end

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

dlg:show { wait = false }