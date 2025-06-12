dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")

local areaTargets <const> = { "ACTIVE", "SELECTION" }
local palTargets <const> = { "ACTIVE", "FILE" }

local defaults <const> = {
    -- Last commit with older paletteFromCel:
    -- cc630e248ff36932387f9adfdf56925e53463c0b .
    areaTarget = "ACTIVE",
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
    palTarget = "ACTIVE",
    paletteIndex = 1,
}

local dlg <const> = Dialog { title = "Palette From Cel" }

dlg:combobox {
    id = "areaTarget",
    label = "Target:",
    option = defaults.areaTarget,
    options = areaTargets,
    focus = false,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "palTarget",
    label = "Palette:",
    option = defaults.palTarget,
    options = palTargets,
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data
        local palTarget <const> = args.palTarget --[[@as string]]

        dlg:modify {
            id = "paletteIndex",
            visible = palTarget == "ACTIVE"
        }
        dlg:modify {
            id = "filepath",
            visible = palTarget == "FILE"
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
    visible = defaults.palTarget == "ACTIVE"
}

dlg:newrow { always = false }

dlg:file {
    id = "filepath",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
    basepath = app.fs.userDocsPath,
    save = true,
    visible = defaults.palTarget == "FILE"
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Mask:",
    text = "Prepend",
    selected = defaults.prependMask,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "removeAlpha",
    label = "Opaque Colors:",
    selected = defaults.removeAlpha,
    hexpand = false,
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
    hexpand = false,
    onclick = function()
        local args <const> = dlg.data
        local clamp <const> = args.clampTo256 --[[@as boolean]]
        local removeAlpha <const> = args.removeAlpha --[[@as boolean]]
        local octCap <const> = args.octCapacity --[[@as integer]]
        local octThreshold <const> = args.octThreshold --[[@as integer]]

        dlg:modify { id = "octThreshold", visible = clamp }
        dlg:modify { id = "octCapacity", visible = clamp }
        dlg:modify { id = "refineCapacity", visible = clamp and (octCap > 8) }
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

        local r = (1 << octCap) // 2 --[[@as integer]]
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

dlg:check {
    id = "printElapsed",
    label = "Print:",
    text = "Diagnostic",
    selected = defaults.printElapsed,
    visible = defaults.clampTo256,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
    onclick = function()
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

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local colorSpace <const> = spriteSpec.colorSpace
        local alphaIndex <const> = spriteSpec.transparentColor

        local srcImg = nil
        local xtl = 0
        local ytl = 0

        local args <const> = dlg.data
        local areaTarget <const> = args.areaTarget
            or defaults.areaTarget --[[@as string]]
        if areaTarget == "SELECTION" then
            local mask <const>, isValid <const> = AseUtilities.getSelection(
                activeSprite)
            if not isValid then
                app.alert {
                    title = "Error",
                    text = "There is no valid selection."
                }
                return
            end
            srcImg, xtl, ytl = AseUtilities.selToImage(
                mask, activeSprite, srcFrame.frameNumber)
        else
            -- Default to active layer.
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

            if srcLayer.isGroup then
                local isValid <const>,
                flatImg <const>,
                xTlFlat <const>,
                yTlFlat <const> = AseUtilities.flatToImage(
                    srcLayer, srcFrame,
                    colorMode, colorSpace, alphaIndex,
                    true, false, true, true)

                srcImg = flatImg
                xtl = xTlFlat
                ytl = yTlFlat
            else
                local srcCel <const> = srcLayer:cel(srcFrame)
                if not srcCel then
                    app.alert {
                        title = "Error",
                        text = "There is no active cel."
                    }
                    return
                end

                if srcLayer.isTilemap then
                    srcImg = AseUtilities.tileMapToImage(
                        srcCel.image, srcLayer.tileset, colorMode)
                else
                    srcImg = srcCel.image
                end

                local srcPos <const> = srcCel.position
                xtl = srcPos.x
                ytl = srcPos.y
            end -- End group layer check.
        end     -- End area target type.

        local srcBytes <const> = srcImg.bytes
        local wSrcImg <const> = srcImg.width
        local hSrcImg <const> = srcImg.height
        local areaSrcImg <const> = wSrcImg * hSrcImg

        ---@type table<integer, integer>
        local hexDict <const> = {}
        local lenHexDict = 0
        local removeAlpha <const> = args.removeAlpha --[[@as boolean]]
        local a32Mask <const> = removeAlpha and 0xff000000 or 0

        -- Cache methods used in loops.
        local strbyte <const> = string.byte
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack
        local aseToHex <const> = AseUtilities.aseColorToHex

        -- Code is similar to AseUtilities.averageColor, but hex dict value
        -- is slightly different.
        if colorMode == ColorMode.INDEXED then
            local palette <const> = AseUtilities.getPalette(
                srcFrame.frameNumber, activeSprite.palettes)
            local lenPalette <const> = #palette
            local cmRgb <const> = ColorMode.RGB

            local i = 0
            while i < areaSrcImg do
                i = i + 1
                local idx <const> = strbyte(srcBytes, i)
                if idx >= 0 and idx < lenPalette then
                    local aseColor <const> = palette:getColor(idx)
                    if aseColor.alpha > 0 then
                        local abgr32 = aseToHex(aseColor, cmRgb)
                        abgr32 = a32Mask | abgr32
                        if not hexDict[abgr32] then
                            lenHexDict = lenHexDict + 1
                            hexDict[abgr32] = lenHexDict
                        end
                    end -- End color alpha gt zero.
                end     -- End map index is in bounds.
            end         -- End pixel loop.
        elseif colorMode == ColorMode.GRAY then
            local i = 0
            while i < areaSrcImg do
                local i2 <const> = i + i
                local av16 <const> = strunpack("<I2", strsub(
                    srcBytes, 1 + i2, 2 + i2))
                local a8 <const> = av16 >> 0x08 & 0xff
                if a8 > 0 then
                    local v8 <const> = av16 & 0xff
                    local abgr32 = a8 << 0x18 | v8 << 0x10 | v8 << 0x08 | v8
                    abgr32 = a32Mask | abgr32
                    if not hexDict[abgr32] then
                        lenHexDict = lenHexDict + 1
                        hexDict[abgr32] = lenHexDict
                    end
                end
                i = i + 1
            end
        else
            -- Default to RGB color mode.
            local i = 0
            while i < areaSrcImg do
                local i4 <const> = i * 4
                local abgr32 = strunpack("<I4", strsub(
                    srcBytes, 1 + i4, 4 + i4))
                if (abgr32 & 0xff000000) ~= 0 then
                    abgr32 = a32Mask | abgr32
                    if not hexDict[abgr32] then
                        lenHexDict = lenHexDict + 1
                        hexDict[abgr32] = lenHexDict
                    end
                end
                i = i + 1
            end
        end

        -- Convert dictionary to set.
        ---@type integer[]
        local hexes = {}
        for k, v in pairs(hexDict) do
            hexes[v] = k
        end

        local octCapBits <const> = args.octCapacity
            or defaults.octCapacityBits --[[@as integer]]
        local refineCap <const> = args.refineCapacity
            or defaults.refineCapacity --[[@as integer]]
        local ocThreshold <const> = args.octThreshold
            or defaults.octThreshold --[[@as integer]]
        local clampTo256 <const> = args.clampTo256 --[[@as boolean]]

        -- The oldLenHexes and centersLen need to be
        -- set here for print diagnostic purposes.
        local oldLenHexes <const> = #hexes
        local lenCenters = 0
        local octCapacity <const> = refineCap + (1 << octCapBits)
        local lenHexes = oldLenHexes
        if clampTo256 and lenHexes > ocThreshold then
            -- Cache methods to local.
            local fromHex <const> = Rgb.fromHexAbgr32
            local toHex <const> = Rgb.toHex
            local octins <const> = Octree.insert
            local labTosRgb <const> = ColorUtilities.srLab2TosRgb
            local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal

            -- Subdivide once so that there are at least 8 colors
            -- returned in cases where an input palette count
            -- is barely over threshold, e.g., 380 over 255.
            local octree <const> = Octree.new(BoundsLab.srLab2(), octCapacity, 1)
            Octree.subdivide(octree, 1, octCapacity)

            -- This shouldn't need to check for transparent
            -- colors, as they would've been filtered above.
            local i = 0
            while i < lenHexes do
                i = i + 1
                octins(octree, sRgbToLab(fromHex(hexes[i])))
            end

            Octree.cull(octree)

            local centers <const> = Octree.centersMean(octree, {})
            table.sort(centers)

            lenCenters = #centers
            ---@type integer[]
            local centerHexes <const> = {}
            local j = 0
            while j < lenCenters do
                j = j + 1
                centerHexes[j] = toHex(labTosRgb(centers[j]))
            end

            hexes = centerHexes
            lenHexes = #hexes
        end

        local prependMask <const> = args.prependMask --[[@as boolean]]
        if prependMask then
            Utilities.prependMask(hexes)
        end

        local palTarget <const> = args.palTarget
            or defaults.palTarget --[[@as string]]
        if palTarget == "FILE" then
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
            local palIdx <const> = args.paletteIndex
                or defaults.paletteIndex --[[@as integer]]
            local palIdxVerif = 1
            if palIdx <= #activeSprite.palettes then
                palIdxVerif = palIdx
            end

            if colorMode == ColorMode.INDEXED then
                AseUtilities.changePixelFormat(ColorMode.RGB)
                AseUtilities.setPalette(hexes, activeSprite, palIdxVerif)
                AseUtilities.changePixelFormat(ColorMode.INDEXED)
            else
                AseUtilities.setPalette(hexes, activeSprite, palIdxVerif)
            end
        end

        app.refresh()

        local printElapsed <const> = args.printElapsed --[[@as boolean]]
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
                txtArr[#txtArr + 1] = string.format("Capacity: %d", octCapacity)
                txtArr[#txtArr + 1] = string.format("Octree Colors: %d", lenCenters)
            end

            app.alert { title = "Diagnostic", text = txtArr }
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