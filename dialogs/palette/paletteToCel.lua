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
    cvgRad = 175,
    cvgCapacity = 16,
    printElapsed = false,
    clrSpacePreset = "LINEAR_RGB",
    pullFocus = false
}

local function clrToVec3sRgb(clr)
    return Vec3.new(clr.r, clr.g, clr.b)
end

local function clrToVec3lRgb(clr)
    local lin = Clr.standardToLinear(clr)
    return Vec3.new(lin.r, lin.g, lin.b)
end

local function clrToVec3Xyz(clr)
    local xyz = Clr.rgbaToXyz(clr)
    return Vec3.new(xyz.x, xyz.y, xyz.z)
end

local function clrToVec3Lab(clr)
    local lab = Clr.rgbaToLab(clr)
    return Vec3.new(lab.a, lab.b, lab.l)
end

local function clrToVec3Lch(clr)
    local lch = Clr.rgbaToLch(clr)
    return Vec3.new(lch.h, lch.c, lch.l)
end

local function vec3ToClrsRgb(v)
    return Clr.new(v.x, v.y, v.z, 1.0)
end

local function vec3ToClrlRgb(v)
    local lin = Clr.new(v.x, v.y, v.z, 1.0)
    return Clr.linearToStandard(lin)
end

local function vec3ToClrXyz(v)
    return Clr.xyzToRgba(v.x, v.y, v.z, 1.0)
end

local function vec3ToClrLab(v)
    return Clr.labToRgba(v.z, v.x, v.y, 1.0)
end

local function vec3ToClrLch(v)
    return Clr.lchToRgba(v.z, v.y, v.x, 1.0)
end

local function clrToV3FuncFromPreset(preset)
    if preset == "CIE_LAB" then
        return clrToVec3Lab
    elseif preset == "CIE_LCH" then
        return clrToVec3Lch
    elseif preset == "CIE_XYZ" then
        return clrToVec3Xyz
    elseif preset == "LINEAR_RGB" then
        return clrToVec3lRgb
    else
        return clrToVec3sRgb
    end
end

local function v3ToClrFuncFromPreset(preset)
    if preset == "CIE_LAB" then
        return vec3ToClrLab
    elseif preset == "CIE_LCH" then
        return vec3ToClrLch
    elseif preset == "CIE_XYZ" then
        return vec3ToClrXyz
    elseif preset == "LINEAR_RGB" then
        return vec3ToClrlRgb
    else
        return vec3ToClrsRgb
    end
end

local dlg = Dialog { title = "Adopt Palette" }

dlg:slider {
    id = "cvgRad",
    label = "Radius:",
    min = 25,
    max = 250,
    value = defaults.cvgRad
}

dlg:slider {
    id = "cvgCapacity",
    label = "Cell Capacity:",
    min = 3,
    max = 32,
    value = defaults.cvgCapacity
}

dlg:check {
    id = "copyToLayer",
    label = "Copy To New Layer:",
    selected = defaults.copyToLayer
}

dlg:check {
    id = "printElapsed",
    label = "Print Diagnostic:",
    selected = defaults.printElapsed
}

dlg:combobox {
    id = "clrSpacePreset",
    label = "Color Space:",
    option = defaults.clrSpacePreset,
    options = colorSpaces
}

dlg:button {
    id = "ok",
    text = "OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then

                local srcPal = nil
                local palType = args.palType
                if palType == "FILE" then
                    local fp =  args.palFile
                    if fp and #fp > 0 then
                        srcPal = Palette { fromFile = fp }
                    end
                elseif palType == "PRESET" then
                    local pr = args.palPreset
                    if pr and #pr > 0 then
                        srcPal = Palette { fromResource = pr }
                    end
                else
                    srcPal = sprite.palettes[1]
                end

                if srcPal then

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
                            local srcpxitr = srcImg:pixels()
                            local hexesUnique = {}
                            for elm in srcpxitr do
                                hexesUnique[elm()] = true
                            end

                            -- Select which conversion functions to use.
                            local clrSpacePreset = args.clrSpacePreset
                            local clrV3Func = clrToV3FuncFromPreset(clrSpacePreset)
                            local v3ClrFunc = v3ToClrFuncFromPreset(clrSpacePreset)

                            -- Create a dictionary where unique hexes are associated
                            -- with Vec3 queries to an octree.
                            local queries = {}
                            for k, _ in pairs(hexesUnique) do
                                local clr = Clr.fromHex(k)
                                local pt = clrV3Func(clr)
                                table.insert(queries, { hex = k, point = pt })
                            end

                            -- Convert source palette colors to points
                            -- inserted into octree.
                            local srcPalLen = #srcPal
                            local palPts = {}
                            for i = 0, srcPalLen - 1, 1 do
                                local aseColor = srcPal:getColor(i)
                                local clr = AseUtilities.aseColorToClr(aseColor)
                                local pt = clrV3Func(clr)
                                table.insert(palPts, pt)
                            end

                            -- Create an octree.
                            local cvgCapacity = args.cvgCapacity
                            local octBounds = Bounds3.fromPoints(palPts)
                            local octree = Octree.new(octBounds, cvgCapacity, 0)
                            Octree.insertAll(octree, palPts)
                            -- print(octree)

                            -- Find nearest color in palette.
                            local cvgRad = args.cvgRad
                            local correspDict = {}
                            for i = 1, #queries, 1 do
                                local query = queries[i]
                                local center = query.point
                                local near = Octree.querySpherical(octree, center, cvgRad)
                                local resultHex = 0x00000000
                                if #near > 0 then
                                    local nearestPt = near[1]
                                    local nearestClr = v3ClrFunc(nearestPt)
                                    resultHex = Clr.toHex(nearestClr)
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

                            local copyToLayer = args.copyToLayer
                            if copyToLayer then
                                local trgLayer = sprite:newLayer()
                                trgLayer.name = srcCel.layer.name .. "." .. clrSpacePreset
                                local frame = app.activeFrame or 1
                                local trgCel = sprite:newCel(trgLayer, frame)
                                trgCel.image = trgImg
                                trgCel.position = srcCel.position
                            else
                                srcCel.image = trgImg
                            end

                            if oldMode == ColorMode.INDEXED then
                                app.command.ChangePixelFormat { format = "indexed" }
                            elseif oldMode == ColorMode.GRAY then
                                app.command.ChangePixelFormat { format = "gray" }
                            end

                            app.refresh()

                            if printElapsed then
                                endTime = os.time()
                                elapsed = os.difftime(endTime, startTime)
                                local msg = string.format(
                                    "Start: %d\nEnd: %d\nElapsed: %d",
                                    startTime, endTime, elapsed)
                                print(msg)
                            end
                        else
                            app.alert("The cel has no image.")
                        end
                    else
                        app.alert("There is no active cel.")
                    end
                else
                    app.alert("The source palette could not be found.")
                end
            else
                app.alert("There is no active sprite.")
            end
        else
            app.alert("Dialog arguments are invalid.")
        end
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }