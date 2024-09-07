dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")

local colorSpaces <const> = {
    "LINEAR_RGB",
    "S_RGB",
    "SR_LAB_2"
}

local defaults <const> = {
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

---@param preset string
---@param arr table
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

---@param v3 Vec3
---@return Clr
local function vec3ToClrlRgb(v3)
    local lin <const> = Clr.new(v3.x, v3.y, v3.z, 1.0)
    return Clr.lRgbTosRgbInternal(lin)
end

---@param v3 Vec3
---@return Clr
local function vec3ToClrsRgb(v3)
    return Clr.new(v3.x, v3.y, v3.z, 1.0)
end

---@param v3 Vec3
---@return Clr
local function vec3ToClrSrLab2(v3)
    return Clr.srLab2TosRgb(v3.z, v3.x, v3.y, 1.0)
end

---@param preset string
---@return fun(v3: Vec3): Clr
local function v3ToClrFuncFromPreset(preset)
    if preset == "LINEAR_RGB" then
        return vec3ToClrlRgb
    elseif preset == "SR_LAB_2" then
        return vec3ToClrSrLab2
    else
        return vec3ToClrsRgb
    end
end

local dlg <const> = Dialog { title = "Palette From Cel" }

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
        local args <const> = dlg.data
        local clamp <const> = args.clampTo256 --[[@as boolean]]
        local removeAlpha <const> = args.removeAlpha --[[@as boolean]]
        local octThreshold <const> = args.octThreshold --[[@as integer]]

        dlg:modify {
            id = "alphaWarn",
            visible = clamp and (not removeAlpha)
        }
        dlg:modify {
            id = "alphaWarn",
            text = string.format(
                "Opaque if over %d.",
                octThreshold)
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
        local args <const> = dlg.data
        local clamp <const> = args.clampTo256 --[[@as boolean]]
        local removeAlpha <const> = args.removeAlpha --[[@as boolean]]
        local octCap <const> = args.octCapacity --[[@as integer]]
        local octThreshold <const> = args.octThreshold --[[@as integer]]

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
                octThreshold)
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
        local args <const> = dlg.data
        local octThreshold <const> = args.octThreshold --[[@as integer]]

        dlg:modify {
            id = "alphaWarn",
            text = string.format(
                "Opaque if over %d.",
                octThreshold)
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
        local args <const> = dlg.data
        local octCap <const> = args.octCapacity --[[@as integer]]

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
        local args <const> = dlg.data
        local md <const> = args.target --[[@as string]]

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
    filetypes = AseUtilities.FILE_FORMATS_PAL,
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
        local args <const> = dlg.data
        local printElapsed <const> = args.printElapsed --[[@as boolean]]
        local startTime <const> = os.clock()

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

        local srcFrame <const> = site.frame
        if not srcFrame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
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

        if srcLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        AseUtilities.preserveForeBack()

        -- Unpack arguments.
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local ocThreshold <const> = args.octThreshold
            or defaults.octThreshold --[[@as integer]]
        local clampTo256 <const> = args.clampTo256 --[[@as boolean]]
        local prependMask <const> = args.prependMask --[[@as boolean]]
        local removeAlpha <const> = args.removeAlpha --[[@as boolean]]
        local octCapBits <const> = args.octCapacity
            or defaults.octCapacityBits --[[@as integer]]
        local refineCap <const> = args.refineCapacity
            or defaults.refineCapacity --[[@as integer]]

        local srcImg = nil
        local spriteSpec <const> = activeSprite.spec
        local spriteColorMode <const> = spriteSpec.colorMode
        if srcLayer.isGroup then
            local groupRect = nil
            srcImg, groupRect = AseUtilities.flattenGroup(
                srcLayer, srcFrame,
                spriteColorMode,
                spriteSpec.colorSpace,
                spriteSpec.transparentColor,
                true, true, true, true)
        else
            local srcCel <const> = srcLayer:cel(srcFrame)
            if not srcCel then
                app.alert {
                    title = "Error",
                    text = "There is no active cel."
                }
                return
            end
            srcImg = srcCel.image
            if srcLayer.isTilemap then
                srcImg = AseUtilities.tileMapToImage(
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

        local idx = 0
        ---@type table<integer, integer>
        local dictionary <const> = {}
        local pxItr <const> = srcImg:pixels()

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
            local srcPal <const> = AseUtilities.getPalette(
                srcFrame, activeSprite.palettes)
            local aseToHex <const> = AseUtilities.aseColorToHex
            local rgbColorMode <const> = ColorMode.RGB
            local lenSrcPal <const> = #srcPal
            for pixel in pxItr do
                local srcIndex <const> = pixel()
                if srcIndex > -1 and srcIndex < lenSrcPal then
                    local aseColor <const> = srcPal:getColor(srcIndex)
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
                    local a <const> = (hexGray >> 0x08) & 0xff
                    local v <const> = hexGray & 0xff
                    local h <const> = a << 0x18 | v << 0x10 | v << 0x08 | v
                    if not dictionary[h] then
                        idx = idx + 1
                        dictionary[h] = idx
                    end
                end
            end
        end

        -- Convert dictionary to set.
        ---@type integer[]
        local hexes = {}
        for k, v in pairs(dictionary) do
            hexes[v] = k
        end

        -- The oldHexesLen and centersLen need to be
        -- set here for print diagnostic purposes.
        local oldLenHexes <const> = #hexes
        local lenCenters = 0
        local octCapacity <const> = refineCap + (1 << octCapBits)
        local lenHexes = oldLenHexes
        if clampTo256 and lenHexes > ocThreshold then
            local clrSpacePreset <const> = args.clrSpacePreset
                or defaults.clrSpacePreset --[[@as string]]

            -- Cache methods to local.
            local fromHex <const> = Clr.fromHex
            local toHex <const> = Clr.toHex
            local octins <const> = Octree.insert
            local clrV3Func <const> = clrToV3FuncFromPreset(clrSpacePreset)
            local v3ClrFunc <const> = v3ToClrFuncFromPreset(clrSpacePreset)

            -- Subdivide once so that there are at least 8 colors
            -- returned in cases where an input palette count
            -- is barely over threshold, e.g., 380 over 255.
            local bounds <const> = boundsFromPreset(clrSpacePreset)
            local octree <const> = Octree.new(bounds, octCapacity, 1)
            Octree.subdivide(octree, 1, octCapacity)

            -- This shouldn't need to check for transparent
            -- colors, as they would've been filtered above.
            local i = 0
            while i < lenHexes do
                i = i + 1
                local clr <const> = fromHex(hexes[i])
                octins(octree, clrV3Func(clr))
            end

            Octree.cull(octree)

            local centers <const> = Octree.centersMean(octree, {})
            sortByPreset(clrSpacePreset, centers)

            lenCenters = #centers
            ---@type integer[]
            local centerHexes <const> = {}
            local j = 0
            while j < lenCenters do
                j = j + 1
                local srgb <const> = v3ClrFunc(centers[j])
                centerHexes[j] = toHex(srgb)
            end

            hexes = centerHexes
            lenHexes = #hexes
        end

        if prependMask then
            Utilities.prependMask(hexes)
        end

        if target == "SAVE" then
            local filepath <const> = args.filepath --[[@as string]]
            local palette <const> = Palette(lenHexes)
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
            local palIdx <const> = args.paletteIndex
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
            local endTime <const> = os.clock()
            local elapsed <const> = endTime - startTime

            local txtArr <const> = {
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

dlg:show {
    autoscrollbars = true,
    wait = false
}