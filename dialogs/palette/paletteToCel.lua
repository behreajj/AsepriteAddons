dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")
dofile("../../support/clr.lua")

local colorSpaces = {
    "CIE_LAB",
    "CIE_XYZ",
    "LINEAR_RGB",
    "S_RGB"
}

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "RANGE",
    palType = "ACTIVE",
    copyToLayer = true,
    cvgLabRad = 175,
    cvgNormRad = 120,
    octCapacityBits = 4,
    minCapacityBits = 2,
    maxCapacityBits = 16,
    printElapsed = false,
    clrSpacePreset = "LINEAR_RGB",
    pullFocus = false
}

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

local dlg = Dialog { title = "Palette To Cel" }

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
    options = { "ACTIVE", "FILE", "PRESET" },
    onchange = function()
        local state = dlg.data.palType
        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
        }
        dlg:modify {
            id = "palPreset",
            visible = state == "PRESET"
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

dlg:entry {
    id = "palPreset",
    text = "",
    focus = false,
    visible = defaults.palType == "PRESET"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "clrSpacePreset",
    label = "Color Space:",
    option = defaults.clrSpacePreset,
    options = colorSpaces,
    onchange = function()
        local state = dlg.data.clrSpacePreset
        local isLab = state == "CIE_LAB"
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
}

dlg:newrow { always = false }

dlg:slider {
    id = "cvgNormRad",
    label = "Radius:",
    min = 5,
    max = 174,
    value = defaults.cvgNormRad,
    visible = defaults.clrSpacePreset ~= "CIE_LAB"
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
    id = "copyToLayer",
    label = "As New Layer:",
    selected = defaults.copyToLayer
}

dlg:newrow { always = false }

dlg:check {
    id = "printElapsed",
    label = "Print Diagnostic:",
    selected = defaults.printElapsed
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert{
                title = "Error",
                text = "There is no active sprite." }
            return
        end

        local srcLayer = app.activeLayer
        if not srcLayer then
            app.alert{
                title = "Error",
                text = "There is no active sprite." }
            return
        end

        -- Begin timing the function elapsed.
        local args = dlg.data
        local printElapsed = args.printElapsed
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then
            startTime = os.time()
        end

        local oldMode = activeSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        -- Cache global methods.
        local fromHex = Clr.fromHex
        local v3Hash = Vec3.hashCode
        local octInsert = Octree.insert
        local search = Octree.queryInternal

        -- Convert source palette colors to points
        -- inserted into octree.
        local hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
            args.palType, args.palFile, args.palPreset)

        -- Select which conversion functions to use.
        local clrSpacePreset = args.clrSpacePreset
        local octBounds = boundsFromPreset(clrSpacePreset)
        local clrV3Func = clrToV3FuncFromPreset(clrSpacePreset)

        -- Select query radius according to color space.
        local cvgRad = 0.0
        if clrSpacePreset == "CIE_LAB" then
            cvgRad = args.cvgLabRad
        else
            cvgRad = args.cvgNormRad * 0.01
        end

        -- Create octree.
        local ptToHexDict = {}
        -- local exactMatches = {}
        local hexesSrgbLen = #hexesSrgb
        local octCapacity = args.octCapacity
            or defaults.octCapacityBits
        octCapacity = 2 ^ octCapacity
        local octree = Octree.new(octBounds, octCapacity, 1)
        local hexIdx = 0
        while hexIdx < hexesSrgbLen do
            hexIdx = hexIdx + 1
            local hexSrgb = hexesSrgb[hexIdx]
            if (hexSrgb & 0xff000000) ~= 0 then
                local clr = fromHex(hexSrgb)
                local pt = clrV3Func(clr)
                local hexProfile = hexesProfile[hexIdx]
                -- exactMatches[hexProfile] = true
                ptToHexDict[v3Hash(pt)] = hexProfile
                octInsert(octree, pt)
            end
        end

        Octree.cull(octree)

        -- Find frames from target.
        local frames = {}
        local target = args.target
        if target == "ACTIVE" then
            local activeFrame = app.activeFrame
            if activeFrame then
                frames[1] = activeFrame
            end
        elseif target == "RANGE" then
            local appRange = app.range
            local rangeFrames = appRange.frames
            local rangeFramesLen = #rangeFrames
            for i = 1, rangeFramesLen, 1 do
                frames[i] = rangeFrames[i]
            end
        else
            local activeFrames = activeSprite.frames
            local activeFramesLen = #activeFrames
            for i = 1, activeFramesLen, 1 do
                frames[i] = activeFrames[i]
            end
        end

        -- Create a new layer if necessary.
        local copyToLayer = args.copyToLayer
        local trgLayer = nil
        if copyToLayer then
            trgLayer = activeSprite:newLayer()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = srcLayerName .. "." .. clrSpacePreset
            if srcLayer.opacity then
                trgLayer.opacity = srcLayer.opacity
            end
            if srcLayer.blendMode then
                trgLayer.blendMode = srcLayer.blendMode
            end
        end

        local framesLen = #frames
        app.transaction(function()
            local i = 0
            while i < framesLen do
                i = i + 1
                local srcFrame = frames[i]
                local srcCel = srcLayer:cel(srcFrame)
                if srcCel then
                    local srcImg = srcCel.image

                    -- Get unique hexadecimal values from image.
                    -- There's no need to preserve order.
                    local srcPxItr = srcImg:pixels()
                    local hexesUnique = {}
                    for elm in srcPxItr do
                        hexesUnique[elm()] = true
                    end

                    -- Create a table where unique hexes are associated
                    -- with Vec3 queries to an octree.
                    local queries = {}
                    local queryCount = 1
                    for k, _ in pairs(hexesUnique) do
                        local clr = fromHex(k)
                        local pt = clrV3Func(clr)
                        queries[queryCount] = { hex = k, point = pt }
                        queryCount = queryCount + 1
                    end

                    -- Find nearest color in palette.
                    local correspDict = {}
                    local lenQueries = #queries
                    local j = 0
                    while j < lenQueries do
                        j = j + 1
                        local query = queries[j]
                        local queryHex = query.hex
                        local resultHex = 0x0
                        -- if exactMatches[queryHex] then
                            -- resultHex = queryHex
                        -- else
                            local nearPoint, _ = search(
                                octree, query.point, cvgRad)
                            if nearPoint then
                                local hsh = v3Hash(nearPoint)
                                resultHex = ptToHexDict[hsh]
                            end
                        -- end
                        correspDict[queryHex] = resultHex
                    end

                    -- Apply colors to image.
                    -- Use source color alpha.
                    local trgImg = srcImg:clone()
                    local trgpxitr = trgImg:pixels()
                    for elm in trgpxitr do
                        local srcHex = elm()
                        elm(srcHex & 0xff000000
                            | correspDict[srcHex] & 0x00ffffff)
                    end

                    if copyToLayer then
                        local trgCel = activeSprite:newCel(
                            trgLayer, srcFrame,
                            trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    else
                        srcCel.image = trgImg
                    end
                end
            end
        end)

        AseUtilities.changePixelFormat(oldMode)
        app.refresh()

        if printElapsed then
            endTime = os.time()
            elapsed = os.difftime(endTime, startTime)
            app.alert {
                title = "Diagnostic",
                text = {
                    string.format("Start: %d", startTime),
                    string.format("End: %d", endTime),
                    string.format("Elapsed: %d", elapsed)
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

dlg:show { wait = false }
