dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")
dofile("../../support/clr.lua")

local colorSpaces = {
    "CIE_LAB",
    "CIE_XYZ",
    "LINEAR_RGB",
    "S_RGB"
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
    if preset == "CIE_LAB" then
        return Bounds3.cieLab()
    else
        return Bounds3.unitCubeUnsigned()
    end
end

local function clrToVec3sRgb(clr)
    return Vec3.new(clr.r, clr.g, clr.b)
end

local function clrToVec3lRgb(clr)
    local lin = Clr.sRgbaTolRgbaInternal(clr)
    return Vec3.new(lin.r, lin.g, lin.b)
end

local function clrToVec3Xyz(clr)
    local xyz = Clr.sRgbaToXyz(clr)
    return Vec3.new(xyz.x, xyz.y, xyz.z)
end

local function clrToVec3Lab(clr)
    local lab = Clr.sRgbaToLab(clr)
    return Vec3.new(lab.a, lab.b, lab.l)
end

local function clrToV3FuncFromPreset(preset)
    if preset == "CIE_LAB" then
        return clrToVec3Lab
    elseif preset == "CIE_XYZ" then
        return clrToVec3Xyz
    elseif preset == "LINEAR_RGB" then
        return clrToVec3lRgb
    else
        return clrToVec3sRgb
    end
end

local function vec3ToClrLab(v3)
    return Clr.labTosRgba(v3.z, v3.x, v3.y, 1.0)
end

local function vec3ToClrXyz(v3)
    return Clr.xyzaTosRgba(v3.x, v3.y, v3.z, 1.0)
end

local function vec3ToClrlRgb(v3)
    local lin = Clr.new(v3.x, v3.y, v3.z, 1.0)
    return Clr.lRgbaTosRgbaInternal(lin)
end

local function vec3ToClrsRgb(v3)
    return Clr.new(v3.x, v3.y, v3.z, 1.0)
end

local function v3ToClrFuncFromPreset(preset)
    if preset == "CIE_LAB" then
        return vec3ToClrLab
    elseif preset == "CIE_XYZ" then
        return vec3ToClrXyz
    elseif preset == "LINEAR_RGB" then
        return vec3ToClrlRgb
    else
        return vec3ToClrsRgb
    end
end

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
            visible = state and (not removeAlpha) }
        dlg:modify {
            id = "alphaWarn",
            text = string.format(
                "Opaque if over %d.",
                args.octThreshold) }
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
        local state = args.clampTo256
        local removeAlpha = args.removeAlpha
        local octCap = args.octCapacity
        dlg:modify { id = "octThreshold", visible = state }
        dlg:modify { id = "octCapacity", visible = state }
        dlg:modify { id = "refineCapacity", visible = state and (octCap > 8) }
        dlg:modify { id = "clrSpacePreset", visible = state }
        dlg:modify { id = "printElapsed", visible = state }
        dlg:modify {
            id = "alphaWarn",
            visible = state and (not removeAlpha) }
        dlg:modify {
            id = "alphaWarn",
            text = string.format(
                "Opaque if over %d.",
                args.octThreshold) }
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
                args.octThreshold) }
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

        local r = (2 ^ octCap) // 2
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
    label = "Print Diagnostic:",
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
        local printElapsed = args.printElapsed
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then startTime = os.time() end

        -- Early returns.
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert("There is no active sprite.")
            return
        end

        local activeCel = app.activeCel
        if not activeCel then
            app.alert("There is no active cel.")
            return
        end

        -- Unpack arguments.
        local removeAlpha = args.removeAlpha
        local target = args.target
        local ocThreshold = args.octThreshold or defaults.octThreshold
        local clampTo256 = args.clampTo256
        local prependMask = args.prependMask

        local image = activeCel.image
        local itr = image:pixels()
        local dictionary = {}
        local idx = 1

        local alphaMask = 0
        local colorMode = activeSprite.colorMode
        if removeAlpha then
            if colorMode == ColorMode.GRAY then
                alphaMask = 0xff00
            else
                alphaMask = 0xff000000
            end
        end

        -- In Aseprite 1.3, it's possible for images in
        -- tile map layers to have a colorMode of 4.
        if colorMode == ColorMode.RGB then
            for elm in itr do
                local hex = elm()
                if ((hex >> 0x18) & 0xff) > 0 then
                    hex = alphaMask | hex
                    if not dictionary[hex] then
                        dictionary[hex] = idx
                        idx = idx + 1
                    end
                end
            end
        elseif colorMode == ColorMode.INDEXED then
            local palettes = activeSprite.palettes
            local lenPalettes = #palettes

            -- TODO: Formalize this into AseUtilities.
            -- tryGetPaletteFromFrame?
            local actFrIdx = 1
            if app.activeFrame then
                actFrIdx = app.activeFrame.frameNumber
                if actFrIdx > lenPalettes then actFrIdx = 1 end
            end
            local srcPal = palettes[actFrIdx]

            local srcPalLen = #srcPal
            for elm in itr do
                local srcIndex = elm()
                if srcIndex > -1 and srcIndex < srcPalLen then
                    local aseColor = srcPal:getColor(srcIndex)
                    if aseColor.alpha > 0 then
                        local hex = aseColor.rgbaPixel
                        hex = alphaMask | hex
                        if not dictionary[hex] then
                            dictionary[hex] = idx
                            idx = idx + 1
                        end
                    end
                end
            end
        elseif colorMode == ColorMode.GRAY then
            for elm in itr do
                local hexGray = elm()
                if ((hexGray >> 0x08) & 0xff) > 0 then
                    hexGray = alphaMask | hexGray
                    local a = (hexGray >> 0x08) & 0xff
                    local v = hexGray & 0xff
                    local hex = a << 0x18 | v << 0x10 | v << 0x08 | v
                    if not dictionary[hex] then
                        dictionary[hex] = idx
                        idx = idx + 1
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
        local octCapBits = args.octCapacity
            or defaults.octCapacityBits
        local refineCap = args.refineCapacity or defaults.refineCapacity
        local octCapacity = refineCap + 2 ^ octCapBits
        local lenHexes = oldLenHexes
        if clampTo256 and lenHexes > ocThreshold then
            local clrSpacePreset = args.clrSpacePreset
                or defaults.clrSpacePreset

            local fromHex = Clr.fromHex
            local toHex = Clr.toHex
            local octins = Octree.insert
            local clrV3Func = clrToV3FuncFromPreset(clrSpacePreset)
            local v3ClrFunc = v3ToClrFuncFromPreset(clrSpacePreset)
            local bounds = boundsFromPreset(clrSpacePreset)

            -- Subdivide this once so that there are at least 8
            -- colors returned in cases where an input palette
            -- count is just barely over the threshold, e.g.,
            -- 380 is over 255.
            local octree = Octree.new(bounds, octCapacity, 1)
            Octree.subdivide(octree, 1, octCapacity)

            local i = 0
            while i < lenHexes do
                i = i + 1
                local hex = hexes[i]
                if (hex & 0xff000000) ~= 0 then
                    local clr = fromHex(hex)
                    local point = clrV3Func(clr)
                    octins(octree, point)
                end
            end

            Octree.cull(octree)

            local centers = Octree.centersMean(octree, false, {})
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
            local filepath = args.filepath
            local palette = Palette(lenHexes)
            for i = 1, lenHexes, 1 do
                palette:setColor(i - 1,
                    AseUtilities.hexToAseColor(hexes[i]))
            end
            palette:saveAs(filepath)
            app.alert("Palette saved.")
        else
            -- How to handle out of bounds palette index?
            local palIdx = args.paletteIndex or defaults.paletteIndex
            if palIdx > #activeSprite.palettes then
                app.alert("Palette index is out of bounds.")
                return
            end

            if colorMode == ColorMode.INDEXED then
                -- Not sure how to get around this...
                app.command.ChangePixelFormat { format = "rgb" }
                AseUtilities.setSpritePalette(hexes, activeSprite, palIdx)
                app.command.ChangePixelFormat { format = "indexed" }
            elseif colorMode == ColorMode.GRAY then
                AseUtilities.setSpritePalette(hexes, activeSprite, palIdx)
            else
                AseUtilities.setSpritePalette(hexes, activeSprite, palIdx)
            end

        end

        if printElapsed then
            endTime = os.time()
            elapsed = os.difftime(endTime, startTime)

            local txtArr = {
                string.format("Start: %d", startTime),
                string.format("End: %d", endTime),
                string.format("Elapsed: %d", elapsed),
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
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
