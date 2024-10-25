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
        local max <const> = math.max
        local min <const> = math.min
        local sqrt <const> = math.sqrt
        local floor <const> = math.floor

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
        local spriteWidth <const> = activeSprite.width
        local spriteHeight <const> = activeSprite.height
        local spriteSpec <const> = activeSprite.spec
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

        local hexBlank = 0xff000000 | hexDefault
        local alphaPart = 0xff
        if preserveAlpha then
            hexBlank = 0x0
            alphaPart = 0x0
        end

        -- In the event that the image is trimmed.
        local activeWidth <const> = spriteWidth
        local activeHeight <const> = spriteHeight

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
            activeWidth, activeHeight, ColorMode.RGB, ColorSpace())

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
                local flatIdx = 0
                local lMin = 2147483647
                local lMax = -2147483648

                -- TODO: Switch to using string bytes approach?

                -- Cache pixels from pixel iterator.
                local flatPxItr <const> = flatImg:pixels()
                for pixel in flatPxItr do
                    flatIdx = flatIdx + 1
                    local hex <const> = pixel()
                    local alpha <const> = (hex >> 0x18) & 0xff
                    alphaTable[flatIdx] = alpha

                    local lum = 0.0
                    if alpha > 0 then
                        local clr <const> = Clr.fromHexAbgr32(hex)
                        local lab <const> = Clr.sRgbToSrLab2(clr)
                        lum = lab.l * 0.01
                    end

                    lumTable[flatIdx] = lum
                    if lum < lMin then lMin = lum end
                    if lum > lMax then lMax = lum end
                end

                -- Stretch contrast.
                -- A color disc with uniform perceptual luminance
                -- generated by Okhsl has a range of about 0.069.
                if stretchContrast and lMax > lMin then
                    local rangeLum <const> = math.abs(lMax - lMin)
                    if rangeLum > 0.07 then
                        local invRangeLum <const> = 1.0 / rangeLum
                        local lenLum <const> = #lumTable
                        local j = 0
                        while j < lenLum do
                            j = j + 1
                            local lum <const> = lumTable[j]
                            lumTable[j] = (lum - lMin) * invRangeLum
                        end
                    end
                end

                -- Show gray image.
                if grayLayer then
                    local grayImg <const> = Image(specNone)
                    local grayPxItr <const> = grayImg:pixels()
                    local grayIdx = 0
                    for pixel in grayPxItr do
                        grayIdx = grayIdx + 1
                        local alpha <const> = alphaTable[grayIdx]
                        local lum <const> = lumTable[grayIdx]
                        if alpha > 0 then
                            local v <const> = floor(0.5 + lum * 255.0)
                            local hex <const> = alpha << 0x18 | v << 0x10 | v << 0x08 | v
                            pixel(hex)
                        end
                    end

                    activeSprite:newCel(
                        grayLayer, frame, grayImg, originPt)
                end

                local writeIdx = 0
                local normalImg <const> = Image(specNone)
                local normPxItr <const> = normalImg:pixels()

                for pixel in normPxItr do
                    writeIdx = writeIdx + 1
                    local alphaCenter <const> = alphaTable[writeIdx]
                    if alphaCenter > 0 then
                        local yc <const> = pixel.y
                        local yn1 <const> = wrapper(yc - 1, activeHeight)
                        local yp1 <const> = wrapper(yc + 1, activeHeight)

                        local xc <const> = pixel.x
                        local xn1 <const> = wrapper(xc - 1, activeWidth)
                        local xp1 <const> = wrapper(xc + 1, activeWidth)

                        local yn1Index <const> = xc + yn1 * activeWidth
                        local yp1Index <const> = xc + yp1 * activeWidth

                        local ycw <const> = yc * activeWidth
                        local xn1Index <const> = xn1 + ycw
                        local xp1Index <const> = xp1 + ycw

                        -- Treat transparent pixels as zero height.
                        local grayNorth = 0.0
                        local alphaNorth <const> = alphaTable[1 + yn1Index]
                        if alphaNorth > 0 then
                            grayNorth = lumTable[1 + yn1Index]
                        end

                        local grayWest = 0.0
                        local alphaWest <const> = alphaTable[1 + xn1Index]
                        if alphaWest > 0 then
                            grayWest = lumTable[1 + xn1Index]
                        end

                        local grayEast = 0.0
                        local alphaEast <const> = alphaTable[1 + xp1Index]
                        if alphaEast > 0 then
                            grayEast = lumTable[1 + xp1Index]
                        end

                        local graySouth = 0.0
                        local alphaSouth <const> = alphaTable[1 + yp1Index]
                        if alphaSouth > 0 then
                            graySouth = lumTable[1 + yp1Index]
                        end

                        local dx <const> = halfScale * (grayWest - grayEast)
                        local dy <const> = halfScale * (graySouth - grayNorth)

                        local sqMag <const> = dx * dx + dy * dy + 1.0
                        local alphaMask <const> = (alphaCenter | alphaPart) << 0x18
                        if sqMag > 1.0 then
                            local nz = 1.0 / sqrt(sqMag)
                            local nx = min(max(dx * nz, -1.0), 1.0)
                            local ny = min(max(dy * nz, -1.0), 1.0)

                            nx = nx * xFlipNum
                            ny = ny * yFlipNum
                            nz = nz * zFlipNum

                            pixel(alphaMask
                                | (floor(nz * 127.5 + 128.0) << 0x10)
                                | (floor(ny * 127.5 + 128.0) << 0x08)
                                | floor(nx * 127.5 + 128.0))
                        else
                            pixel(alphaMask | hexDefault)
                        end
                    else
                        pixel(hexBlank)
                    end
                end

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