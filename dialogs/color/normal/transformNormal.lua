dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local unitOptions <const> = { "PERCENT", "PIXEL" }
local coordSystems <const> = { "CENTER", "TOP_LEFT" }

local defaults <const> = {
    target = "ACTIVE",
    degrees = 90,
}

local dlg <const> = Dialog { title = "Transform Normals" }

---@param source Image source image
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Image
local function rotz(source, cosa, sina)
    local srcSpec <const> = source.spec
    local colorMode <const> = srcSpec.colorMode
    local alphaIndex <const> = srcSpec.transparentColor

    local trgBytes <const>,
    wTrg <const>,
    hTrg <const> = Utilities.rotatePixelsZ(
        source.bytes, srcSpec.width, srcSpec.height,
        cosa, sina, source.bytesPerPixel, alphaIndex)

    local strsub <const> = string.sub
    local strunpack <const> = string.unpack

    ---@type table<integer, integer>
    local srcTrgDict <const> = {}
    local lenTrg <const> = wTrg * hTrg
    local i = 0
    while i < lenTrg do
        local i4 <const> = i * 4
        local srcAbgr32 <const> = strunpack("<I4", strsub(
            trgBytes, 1 + i4, 4 + i4))
        local trgAbgr32 = 0xffff8080
        if srcTrgDict[srcAbgr32] then
            trgAbgr32 = srcTrgDict[srcAbgr32]
        else
            local rgb <const> = Rgb.fromHexAbgr32(srcAbgr32)
            if rgb.a > 0.0 then
                local v3 <const> = Vec3.new(
                    rgb.r * 2.0 - 1.0,
                    rgb.g * 2.0 - 1.0,
                    rgb.b * 2.0 - 1.0)
                local v3Rot <const> = Vec3.rotateZInternal(v3, cosa, sina)
                local norm <const> = Vec3.normalize(v3Rot)
                local rgbNorm <const> = Rgb.new(
                    norm.x * 0.5 + 0.5,
                    norm.y * 0.5 + 0.5,
                    norm.z * 0.5 + 0.5)
                trgAbgr32 = Rgb.toHex(rgbNorm)
            end
            srcTrgDict[srcAbgr32] = trgAbgr32
        end
        i = i + 1
    end

    local trgSpec <const> = ImageSpec {
        width = wTrg,
        height = hTrg,
        colorMode = colorMode,
        transparentColor = alphaIndex
    }
    trgSpec.colorSpace = srcSpec.colorSpace
    local target <const> = Image(trgSpec)
    target.bytes = trgBytes
    return target
end

dlg:slider {
    id = "degrees",
    label = "Degrees:",
    min = 0,
    max = 360,
    value = defaults.degrees,
}

dlg:newrow { always = false }

dlg:button {
    id = "xRotateButton",
    label = "Rotate:",
    text = "&X",
    focus = true,
    onclick = function()

    end
}

dlg:button {
    id = "yRotateButton",
    text = "&Y",
    focus = false,
    onclick = function()

    end
}

dlg:button {
    id = "zRotateButton",
    text = "&Z",
    focus = true,
    onclick = function()
        -- Early returns.
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        if activeSprite.colorMode ~= ColorMode.RGB then
            return
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local degrees = args.degrees
            or defaults.degrees --[[@as integer]]
        local target <const> = args.target
            or defaults.target --[[@as string]]

        if degrees == 0 or degrees == 360 then return end

        local filterFrames = activeSprite.frames
        if target == "ACTIVE" then
            local activeFrame <const> = site.frame
            if not activeFrame then return end
            filterFrames = { activeFrame }
        end

        local activeLayer <const> = site.layer
        local cels <const> = AseUtilities.filterCels(
            activeSprite, activeLayer, filterFrames, target,
            false, false, false, false)
        local lenCels <const> = #cels

        degrees = 360 - degrees
        local query <const> = AseUtilities.DIMETRIC_ANGLES[degrees]
        local radians <const> = query
            or (0.017453292519943 * degrees)

        -- Avoid trigonometric functions in while loop below.
        -- Cache sine and cosine here, then use formula for
        -- vector rotation.
        local cosa <const> = math.cos(radians)
        local sina <const> = -math.sin(radians)

        -- Cache methods.
        local floor <const> = math.floor
        local trimAlpha <const> = AseUtilities.trimImageAlpha

        app.transaction("Rotate Cels", function()
            local i = 0
            while i < lenCels do
                i = i + 1
                local cel <const> = cels[i]
                local srcImg <const> = cel.image
                if not srcImg:isEmpty() then
                    local celPos <const> = cel.position
                    local xSrcCtr <const> = celPos.x + srcImg.width * 0.5
                    local ySrcCtr <const> = celPos.y + srcImg.height * 0.5

                    local trgImg = rotz(srcImg, cosa, sina)
                    local xtlTrg = xSrcCtr - trgImg.width * 0.5
                    local ytlTrg = ySrcCtr - trgImg.height * 0.5

                    local xTrim = 0
                    local yTrim = 0
                    trgImg, xTrim, yTrim = trimAlpha(trgImg, 0, 0)
                    xtlTrg = xtlTrg + xTrim
                    ytlTrg = ytlTrg + yTrim

                    cel.position = Point(floor(xtlTrg), floor(ytlTrg))
                    cel.image = trgImg
                end -- End source image not empty.
            end     -- End cels loop.
        end)        -- End transaction.
    end
}

dlg:newrow { always = false }

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

local dlgBounds <const> = dlg.bounds
dlg.bounds = Rectangle(
    dlgBounds.x * 2 - 52, dlgBounds.y,
    dlgBounds.w, dlgBounds.h)