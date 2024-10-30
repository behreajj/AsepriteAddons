dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local edges <const> = { "CLAMP", "WRAP" }

local defaults <const> = {
    target = "ACTIVE",
    stretchContrast = false,
    scale = 16,
    edgeType = "CLAMP",
    xFlip = false,
    yFlip = false,
    zFlip = false,
    showFlatMap = false,
    showGrayMap = false,
    preserveAlpha = false,
    pullFocus = false
}

local dlg <const> = Dialog { title = "Normal From Height Map" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:slider {
    id = "scale",
    label = "Slope:",
    min = 1,
    max = 255,
    value = defaults.scale
}

dlg:combobox {
    id = "edgeType",
    label = "Edges:",
    option = defaults.edgeType,
    options = edges
}

dlg:newrow { always = false }

dlg:check {
    id = "stretchContrast",
    label = "Normalize:",
    text = "&Stretch Contrast",
    selected = defaults.stretchContrast
}

dlg:newrow { always = false }

dlg:check {
    id = "xFlip",
    label = "Flip:",
    text = "&X",
    selected = defaults.xFlip
}

dlg:check {
    id = "yFlip",
    text = "&Y",
    selected = defaults.yFlip
}

dlg:check {
    id = "zFlip",
    text = "&Z",
    selected = defaults.zFlip
}

dlg:newrow { always = false }

dlg:check {
    id = "showFlatMap",
    label = "Show:",
    text = "&Flat",
    selected = defaults.showFlatMap
}

dlg:check {
    id = "showGrayMap",
    text = "&Height",
    selected = defaults.showGrayMap
}

dlg:newrow { always = false }

dlg:check {
    id = "preserveAlpha",
    label = "Keep Alpha:",
    selected = defaults.preserveAlpha
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Early returns.
        local activeSprite <const> = app.site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        if activeSprite.colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "The sprite must be in RGB color mode."
            }
            return
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local scale <const> = args.scale
            or defaults.scale --[[@as integer]]
        local stretchContrast <const> = args.stretchContrast --[[@as boolean]]
        local xFlip <const> = args.xFlip --[[@as boolean]]
        local yFlip <const> = args.yFlip --[[@as boolean]]
        local zFlip <const> = args.zFlip --[[@as boolean]]
        local showFlatMap <const> = args.showFlatMap --[[@as boolean]]
        local showGrayMap <const> = args.showGrayMap --[[@as boolean]]
        local preserveAlpha <const> = args.preserveAlpha --[[@as boolean]]

        -- Cache global methods to locals.
        local floor <const> = math.floor
        local max <const> = math.max
        local min <const> = math.min
        local sqrt <const> = math.sqrt
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack
        local tconcat <const> = table.concat

        -- Choose edge wrapping method.
        local edgeType <const> = args.edgeType
            or defaults.edgeType --[[@as string]]
        local wrapper = nil
        if edgeType == "CLAMP" then
            wrapper = function(a, b)
                if a < 0 then return 0 end
                if a >= b then return b - 1 end
                return a
            end
        else
            wrapper = function(a, b)
                return a % b
            end
        end

        -- Choose frames based on input.
        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Held constant in loop to follow.
        local spriteSpec <const> = activeSprite.spec
        local wSprite <const> = spriteSpec.width
        local hSprite <const> = spriteSpec.height
        local areaSprite <const> = wSprite * hSprite
        local halfScale <const> = scale * 0.5
        local originPt <const> = Point(0, 0)
        local lenFrames <const> = #frames

        -- For flipping normals.
        local xFlipNum = 1
        local yFlipNum = 1
        local zFlipNum = 1
        local hexDefault = 0x00ff8080

        if xFlip then xFlipNum = -1 end
        if yFlip then yFlipNum = -1 end
        if zFlip then
            zFlipNum = -1
            hexDefault = 0x00008080
        end

        local hexBlank = 0xff000000 | hexDefault --[[@as integer]]
        local alphaPart = 0xff
        if preserveAlpha then
            hexBlank = 0x0
            alphaPart = 0x0
        end

        -- In the event that the image is trimmed.
        local wActive <const> = wSprite
        local hActive <const> = hSprite

        -- Create necessary layers.
        local flatLayer <const> = showFlatMap
            and activeSprite:newLayer() or nil
        local grayLayer <const> = showGrayMap
            and activeSprite:newLayer() or nil
        local normalLayer <const> = activeSprite:newLayer()

        app.transaction("Set Layer Props", function()
            if flatLayer then
                flatLayer.name = "Flattened"
            end

            if grayLayer then
                grayLayer.name = "Height Map"
            end

            normalLayer.name = string.format("Normal Map %03d", scale)
        end)

        local specNone <const> = AseUtilities.createSpec(
            wActive, hActive, ColorMode.RGB, ColorSpace())
        local areaActive <const> = wActive * hActive

        app.transaction("Normal From Height", function()
            local i = 0
            while i < lenFrames do
                i = i + 1
                local frame <const> = frames[i]

                -- Create flat image.
                local flatImg <const> = Image(spriteSpec)
                flatImg:drawSprite(activeSprite, frame)

                -- Show flattened image.
                if flatLayer then
                    activeSprite:newCel(
                        flatLayer, frame, flatImg, originPt)
                end

                -- Prep variables for loop.
                ---@type number[]
                local lumTable <const> = {}
                ---@type integer[]
                local alphaTable <const> = {}
                local lMin = 2147483647
                local lMax = -2147483648

                local srcBytes <const> = flatImg.bytes
                local j = 0
                while j < areaSprite do
                    local j4 <const> = j * 4
                    local abgr32 <const> = strunpack("<I4", strsub(
                        srcBytes, 1 + j4, 4 + j4))
                    local alpha <const> = (abgr32 >> 0x18) & 0xff

                    local lum = 0.0
                    if alpha > 0 then
                        local clr <const> = Clr.fromHexAbgr32(abgr32)
                        local lab <const> = Clr.sRgbToSrLab2(clr)
                        lum = lab.l * 0.01
                    end

                    if lum < lMin then lMin = lum end
                    if lum > lMax then lMax = lum end

                    j = j + 1
                    alphaTable[j] = alpha
                    lumTable[j] = lum
                end

                -- Stretch contrast.
                -- A color disc with uniform perceptual luminance
                -- generated by Okhsl has a range of about 0.069.
                if stretchContrast and lMax > lMin then
                    local rangeLum <const> = math.abs(lMax - lMin)
                    if rangeLum > 0.07 then
                        local invRangeLum <const> = 1.0 / rangeLum
                        local lenLum <const> = #lumTable
                        local k = 0
                        while k < lenLum do
                            k = k + 1
                            local lum <const> = lumTable[k]
                            lumTable[k] = (lum - lMin) * invRangeLum
                        end
                    end
                end

                -- Show gray image.
                if grayLayer then
                    ---@type string[]
                    local grayByteStrArr <const> = {}
                    local m = 0
                    while m < areaActive do
                        m = m + 1
                        local alpha <const> = alphaTable[m]
                        local abgr32 = 0
                        if alpha > 0 then
                            local lum <const> = lumTable[m]
                            local v8 <const> = floor(lum * 255.0 + 0.5)
                            abgr32 = alpha << 0x18 | v8 << 0x10 | v8 << 0x08 | v8
                        end
                        grayByteStrArr[m] = strpack("<I4", abgr32)
                    end

                    local grayImg <const> = Image(specNone)
                    grayImg.bytes = tconcat(grayByteStrArr)
                    activeSprite:newCel(
                        grayLayer, frame, grayImg, originPt)
                end

                ---@type string[]
                local normalByteStrArr <const> = {}
                local m = 0
                while m < areaActive do
                    local abgr32 = hexBlank
                    local alphaCenter <const> = alphaTable[1 + m]
                    if alphaCenter > 0 then
                        local yc <const> = m // wActive
                        local yn1 <const> = wrapper(yc - 1, hActive)
                        local yp1 <const> = wrapper(yc + 1, hActive)

                        local xc <const> = m % wActive
                        local xn1 <const> = wrapper(xc - 1, wActive)
                        local xp1 <const> = wrapper(xc + 1, wActive)

                        local yn1Index <const> = yn1 * wActive + xc
                        local yp1Index <const> = yp1 * wActive + xc

                        local ycw <const> = yc * wActive
                        local xn1Index <const> = xn1 + ycw
                        local xp1Index <const> = xp1 + ycw

                        -- Treat transparent pixels as zero height.
                        local alphaNorth <const> = alphaTable[1 + yn1Index]
                        local grayNorth = 0.0
                        if alphaNorth > 0 then
                            grayNorth = lumTable[1 + yn1Index]
                        end

                        local alphaWest <const> = alphaTable[1 + xn1Index]
                        local grayWest = 0.0
                        if alphaWest > 0 then
                            grayWest = lumTable[1 + xn1Index]
                        end

                        local alphaEast <const> = alphaTable[1 + xp1Index]
                        local grayEast = 0.0
                        if alphaEast > 0 then
                            grayEast = lumTable[1 + xp1Index]
                        end

                        local alphaSouth <const> = alphaTable[1 + yp1Index]
                        local graySouth = 0.0
                        if alphaSouth > 0 then
                            graySouth = lumTable[1 + yp1Index]
                        end

                        local dx <const> = halfScale * (grayWest - grayEast)
                        local dy <const> = halfScale * (graySouth - grayNorth)

                        local sqMag <const> = dx * dx + dy * dy + 1.0
                        local alphaMask <const> = (alphaCenter | alphaPart) << 0x18

                        abgr32 = alphaMask | hexDefault
                        if sqMag > 1.0 then
                            local nz = 1.0 / sqrt(sqMag)
                            local nx = min(max(dx * nz, -1.0), 1.0)
                            local ny = min(max(dy * nz, -1.0), 1.0)

                            nx = nx * xFlipNum
                            ny = ny * yFlipNum
                            nz = nz * zFlipNum

                            abgr32 = alphaMask
                                | (floor(nz * 127.5 + 128.0) << 0x10)
                                | (floor(ny * 127.5 + 128.0) << 0x08)
                                | floor(nx * 127.5 + 128.0)
                        end
                    end

                    m = m + 1
                    normalByteStrArr[m] = strpack("<I4", abgr32)
                end

                local normalImg <const> = Image(specNone)
                normalImg.bytes = tconcat(normalByteStrArr)

                activeSprite:newCel(
                    normalLayer, frame, normalImg, originPt)
            end
        end)

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