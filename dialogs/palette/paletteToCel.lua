dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")
dofile("../../support/clr.lua")

local colorSpaces = {
    "CIE_LAB",
    "CIE_XYZ",
    "LINEAR_RGB",
    "S_RGB"
}

local defaults = {
    palType = "ACTIVE",
    copyToLayer = true,
    cvgLabRad = 175,
    cvgNormRad = 120,
    cvgCapacity = 16,
    printElapsed = false,
    clrSpacePreset = "LINEAR_RGB",
    pullFocus = false
}

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

-- local function vec3ToClrsRgb(v)
--     return Clr.new(v.x, v.y, v.z, 1.0)
-- end

-- local function vec3ToClrlRgb(v)
--     local lin = Clr.new(v.x, v.y, v.z, 1.0)
--     return Clr.lRgbaTosRgbaInternal(lin)
-- end

-- local function vec3ToClrXyz(v)
--     return Clr.xyzTosRgba(v.x, v.y, v.z, 1.0)
-- end

-- local function vec3ToClrLab(v)
--     return Clr.labTosRgba(v.z, v.x, v.y, 1.0)
-- end

local function boundsFromPreset(preset)
    if preset == "CIE_LAB" then
        return Bounds3.cieLab()
    else
        return Bounds3.unitCubeUnsigned()
    end
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

-- These have been replaced by a point hash placed
-- in a dictionary, but just in case, keep them around.
-- local function v3ToClrFuncFromPreset(preset)
--     if preset == "CIE_LAB" then
--         return vec3ToClrLab
--     elseif preset == "CIE_XYZ" then
--         return vec3ToClrXyz
--     elseif preset == "LINEAR_RGB" then
--         return vec3ToClrlRgb
--     else
--         return vec3ToClrsRgb
--     end
-- end

local dlg = Dialog { title = "Palette To Cel" }

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
    filetypes = { "aseprite", "gpl", "pal" },
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
    id = "cvgCapacity",
    label = "Cell Capacity:",
    min = 3,
    max = 32,
    value = defaults.cvgCapacity
}

dlg:newrow { always = false }

dlg:check {
    id = "copyToLayer",
    label = "Copy To New Layer:",
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
        local args = dlg.data
        local sprite = app.activeSprite
        if sprite then

            -- Add checkbox to exclude transparency mask from
            -- consideration in palette?
            local hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                args.palType, args.palFile, args.palPreset)

            local srcCel = app.activeCel
            if srcCel then

                local srcImg = srcCel.image
                if srcImg ~= nil then

                    local printElapsed = args.printElapsed
                    local startTime = 0
                    local endTime = 0
                    local elapsed = 0
                    if printElapsed then
                        startTime = os.time()
                    end

                    local oldMode = sprite.colorMode
                    app.command.ChangePixelFormat { format = "rgb" }

                    -- Get all unique hexadecimal values from image.
                    -- There's no need to preserve order in this case.
                    local srcPxItr = srcImg:pixels()
                    local hexesUnique = {}
                    for elm in srcPxItr do
                        hexesUnique[elm()] = true
                    end

                    -- Select which conversion functions to use.
                    local clrSpacePreset = args.clrSpacePreset
                    local octBounds = boundsFromPreset(clrSpacePreset)
                    local clrV3Func = clrToV3FuncFromPreset(clrSpacePreset)
                    -- local v3ClrFunc = v3ToClrFuncFromPreset(clrSpacePreset)

                    -- Cache global methods.
                    local fromHex = Clr.fromHex
                    local v3Hash = Vec3.hashCode
                    local insert = Octree.insert
                    local search = Octree.querySphericalInternal

                    -- Create a dictionary where unique hexes are associated
                    -- with Vec3 queries to an octree.
                    local queries = {}
                    for k, _ in pairs(hexesUnique) do
                        local clr = fromHex(k)
                        local pt = clrV3Func(clr)
                        table.insert(queries, { hex = k, point = pt })
                    end

                    -- Convert source palette colors to points
                    -- inserted into octree.
                    -- local octreeBuildStart = os.time()
                    local ptToHexDict = {}
                    local hexesSrgbLen = #hexesSrgb
                    local cvgCapacity = args.cvgCapacity
                    local octree = Octree.new(octBounds, cvgCapacity, 0)
                    for i = 1, hexesSrgbLen, 1 do
                        -- Validate that the color is not an alpha mask.
                        local hexSrgb = hexesSrgb[i]
                        if hexSrgb & 0xff000000 ~= 0 then
                            local clr = fromHex(hexSrgb)
                            local pt = clrV3Func(clr)
                            local hexProfile = hexesProfile[i]
                            ptToHexDict[v3Hash(pt)] = hexProfile
                            insert(octree, pt)
                        end
                    end
                    -- local octreeBuildEnd = os.time()
                    -- print(string.format(
                    --     "Octree Time:\nStart: %d\nEnd: %d\nElapsed: %d",
                    --     octreeBuildStart, octreeBuildEnd,
                    --     os.difftime(octreeBuildEnd, octreeBuildStart)))

                    -- Select query radius according to color space.
                    local cvgRad = 0.0
                    if clrSpacePreset == "CIE_LAB" then
                        cvgRad = args.cvgLabRad
                    else
                        cvgRad = args.cvgNormRad * 0.01
                    end

                    -- Find nearest color in palette.
                    local correspDict = {}
                    local resultLimit = 256
                    for i = 1, #queries, 1 do
                        local query = queries[i]
                        local center = query.point
                        local near = {}
                        search(octree, center, cvgRad, near, resultLimit)
                        local resultHex = 0x00000000
                        if #near > 0 then
                            local nearestPt = near[1].point
                            local ptHash = v3Hash(nearestPt)
                            resultHex = ptToHexDict[ptHash]
                        end
                        correspDict[query.hex] = resultHex
                    end

                    -- Apply colors to image.
                    -- Use source color alpha.
                    local trgImg = srcImg:clone()
                    local trgpxitr = trgImg:pixels()
                    for elm in trgpxitr do
                        local srcHex = elm()
                        local trgHex = correspDict[srcHex]
                        local comp = srcHex & 0xff000000
                                   | trgHex & 0x00ffffff
                        elm(comp)
                    end

                    -- Either copy to new layer or reassign image.
                    local copyToLayer = args.copyToLayer
                    if copyToLayer then
                        local trgLayer = sprite:newLayer()
                        trgLayer.name = srcCel.layer.name .. "." .. clrSpacePreset
                        local frame = app.activeFrame or sprite.frames[1]
                        local trgCel = sprite:newCel(trgLayer, frame)
                        trgCel.image = trgImg
                        trgCel.position = srcCel.position
                    else
                        srcCel.image = trgImg
                    end

                    AseUtilities.changePixelFormat(oldMode)

                    if printElapsed then
                        endTime = os.time()
                        elapsed = os.difftime(endTime, startTime)
                        local msg = string.format(
                            "Start: %d\nEnd: %d\nElapsed: %d\nUnique Colors: %d",
                            startTime, endTime, elapsed, #queries)
                        print(msg)
                    end

                    app.refresh()
                else
                    app.alert("The cel has no image.")
                end
            else
                app.alert("There is no active cel.")
            end
        else
            app.alert("There is no active sprite.")
        end
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