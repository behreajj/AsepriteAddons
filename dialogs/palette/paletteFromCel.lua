dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")
dofile("../../support/clr.lua")

local defaults = {
    removeAlpha = true,
    clampTo256 = true,
    printElapsed = false,
    octThreshold = 256,
    minThreshold = 32,
    maxThreshold = 512,
    octCapacityBits = 9,
    minCapacityBits = 4,
    maxCapacityBits = 12,
    prependMask = true,
    target = "ACTIVE",
    paletteIndex = 1,
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
    -- TODO: Change this to a customizable upper limit?
    id = "clampTo256",
    label = "Octree:",
    text = "At Threshold",
    selected = defaults.clampTo256,
    onclick = function()
        local args = dlg.data
        local state = args.clampTo256
        local removeAlpha = args.removeAlpha
        dlg:modify { id = "octThreshold", visible = state }
        dlg:modify { id = "octCapacity", visible = state }
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
        local oldHexesLen = #hexes
        local centersLen = 0
        local hexesLen = oldHexesLen
        if clampTo256 and hexesLen > ocThreshold then
            local octCapacityBits = args.octCapacity
                or defaults.octCapacityBits
            local octCapacity = 2 ^ octCapacityBits

            local bounds = Bounds3.cieLab()
            local octree = Octree.new(bounds, octCapacity, 1)

            for i = 1, hexesLen, 1 do
                local hex = hexes[i]
                if ((hex >> 0x18) & 0xff) > 0 then
                    local clr = Clr.fromHex(hex)
                    local lab = Clr.sRgbaToLab(clr)
                    local point = Vec3.new(lab.a, lab.b, lab.l)
                    Octree.insert(octree, point)
                end
            end

            local centers = Octree.centers(octree, false)

            -- Centers are sorted by z first, which is the
            -- same as lightness, so default comparator.
            table.sort(centers)

            centersLen = #centers
            local centerHexes = {}
            for i = 1, centersLen, 1 do
                local center = centers[i]
                local srgb = Clr.labTosRgba(
                    center.z, center.x, center.y, 1.0)
                centerHexes[i] = Clr.toHex(srgb)
            end

            hexes = centerHexes
            hexesLen = #hexes
        end

        if prependMask then
            Utilities.prependMask(hexes)
        end

        if target == "SAVE" then
            local filepath = args.filepath
            local palette = Palette(hexesLen)
            for i = 1, hexesLen, 1 do
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
            app.alert {
                title = "Diagnostic",
                text = {
                    string.format("Start: %d", startTime),
                    string.format("End: %d", endTime),
                    string.format("Elapsed: %d", elapsed),
                    string.format("Raw Colors: %d", oldHexesLen),
                    string.format("Octree Colors: %d", centersLen),
                }
            }
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
