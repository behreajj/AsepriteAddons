dofile("../../support/clr.lua")
dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
local edges = { "CLAMP", "WRAP" }

local defaults = {
    target = "RANGE",
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

local dlg = Dialog { title = "Normal From Height Map" }

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
    text = "Stretch Contrast",
    selected = defaults.stretchContrast
}

dlg:newrow { always = false }

dlg:check {
    id = "xFlip",
    label = "Flip:",
    text = "X",
    selected = defaults.xFlip
}

dlg:check {
    id = "yFlip",
    text = "Y",
    selected = defaults.yFlip
}

dlg:check {
    id = "zFlip",
    text = "Z",
    selected = defaults.zFlip
}

dlg:newrow { always = false }

dlg:check {
    id = "showFlatMap",
    label = "Show:",
    text = "Flat",
    selected = defaults.showFlatMap
}

dlg:check {
    id = "showGrayMap",
    text = "Height",
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
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert("There is no active sprite.")
            return
        end

        if activeSprite.colorMode ~= ColorMode.RGB then
            app.alert("The sprite must be in RGB color mode.")
            return
        end

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target
        local scale = args.scale or defaults.scale
        local stretchContrast = args.stretchContrast
        local xFlip = args.xFlip
        local yFlip = args.yFlip
        local zFlip = args.zFlip
        local showFlatMap = args.showFlatMap
        local showGrayMap = args.showGrayMap
        local preserveAlpha = args.preserveAlpha

        -- Cache global methods to locals.
        local max = math.max
        local min = math.min
        local sqrt = math.sqrt
        local trunc = math.tointeger

        -- Choose edge wrapping method.
        local edgeType = args.edgeType or defaults.edgeType
        local wrapper = nil
        if edgeType == "CLAMP" then
            wrapper = function (a, b)
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
        local frames = {}
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

        -- Held constant in loop to follow.
        local spriteWidth = activeSprite.width
        local spriteHeight = activeSprite.height
        local spriteSpec = activeSprite.spec
        local halfScale = scale * 0.5
        local originPt = Point(0, 0)
        local framesLen = #frames

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
        local activeWidth = spriteWidth
        local activeHeight = spriteHeight

        -- Create necessary layers.
        local flatLayer = nil
        local grayLayer = nil

        if showFlatMap then
            flatLayer = activeSprite:newLayer()
            flatLayer.name = "Flattened"
        end

        if showGrayMap then
            grayLayer = activeSprite:newLayer()
            grayLayer.name = "Height.Map"
        end

        local normalLayer = activeSprite:newLayer()
        normalLayer.name = string.format("Normal.Map.%03d", scale)

        local specNone = ImageSpec {
            width = activeWidth,
            height = activeHeight }
        specNone.colorSpace = ColorSpace()

        app.transaction(function()
            for i = 1, framesLen, 1 do
                local frame = frames[i]

                -- Create flat image.
                local flatImg = Image(spriteSpec)
                flatImg:drawSprite(activeSprite, frame)

                -- Show flattened image.
                if showFlatMap then
                    activeSprite:newCel(
                        flatLayer, frame, flatImg, originPt)
                end

                -- Prep variables for loop.
                local lumTable = {}
                local alphaTable = {}
                local flatIdx = 1
                local lMin = 2147483647
                local lMax = -2147483648

                -- Cache pixels from pixel iterator.
                local flatPxItr = flatImg:pixels()
                for elm in flatPxItr do
                    local hex = elm()
                    local alpha = (hex >> 0x18) & 0xff
                    alphaTable[flatIdx] = alpha

                    local lum = 0.0
                    if alpha > 0 then
                        local clr = Clr.fromHex(hex)
                        local lab = Clr.sRgbaToLab(clr)
                        lum = lab.l * 0.01
                    end

                    lumTable[flatIdx] = lum
                    if lum < lMin then lMin = lum end
                    if lum > lMax then lMax = lum end
                    flatIdx = flatIdx + 1
                end

                -- Stretch contrast.
                -- A color disc with uniform perceptual luminance
                -- generated by Okhsl has a range of about 0.069.
                if stretchContrast and lMax > lMin then
                    local rangeLum = math.abs(lMax - lMin)
                    if rangeLum > 0.07 then
                        local invRangeLum = 1.0 / rangeLum
                        local lumLen = #lumTable
                        for j = 1, lumLen, 1 do
                            local lum = lumTable[j]
                            lumTable[j] = (lum - lMin) * invRangeLum
                        end
                    end
                end

                -- Show gray image.
                if showGrayMap then
                    local grayImg = Image(specNone)
                    local grayPxItr = grayImg:pixels()
                    local grayIdx = 1
                    for elm in grayPxItr do
                        local alpha = alphaTable[grayIdx]
                        local lum = lumTable[grayIdx]
                        if alpha > 0 then
                            local v = trunc(0.5 + lum * 255.0)
                            local hex = alpha << 0x18 | v << 0x10 | v << 0x08 | v
                            elm(hex)
                        end
                        grayIdx = grayIdx + 1
                    end

                    activeSprite:newCel(
                        grayLayer, frame, grayImg, originPt)
                end

                local writeIdx = 1
                local normalImg = Image(specNone)
                local normalItr = normalImg:pixels()

                for elm in normalItr do
                    local alphaCenter = alphaTable[writeIdx]
                    if alphaCenter > 0 then
                        local yc = elm.y
                        local yn1 = wrapper(yc - 1, activeHeight)
                        local yp1 = wrapper(yc + 1, activeHeight)

                        local xc = elm.x
                        local xn1 = wrapper(xc - 1, activeWidth)
                        local xp1 = wrapper(xc + 1, activeWidth)

                        local yn1Index = xc + yn1 * activeWidth
                        local yp1Index = xc + yp1 * activeWidth

                        local ycw = yc * activeWidth
                        local xn1Index = xn1 + ycw
                        local xp1Index = xp1 + ycw

                        -- Treat transparent pixels as zero height.
                        local grayNorth = 0.0
                        local alphaNorth = alphaTable[1 + yn1Index]
                        if alphaNorth > 0 then
                            grayNorth = lumTable[1 + yn1Index]
                        end

                        local grayWest = 0.0
                        local alphaWest = alphaTable[1 + xn1Index]
                        if alphaWest > 0 then
                            grayWest = lumTable[1 + xn1Index]
                        end

                        local grayEast = 0.0
                        local alphaEast = alphaTable[1 + xp1Index]
                        if alphaEast > 0 then
                            grayEast = lumTable[1 + xp1Index]
                        end

                        local graySouth = 0.0
                        local alphaSouth = alphaTable[1 + yp1Index]
                        if alphaSouth > 0 then
                            graySouth = lumTable[1 + yp1Index]
                        end

                        local dx = halfScale * (grayWest - grayEast)
                        local dy = halfScale * (graySouth - grayNorth)

                        local sqMag = dx * dx + dy * dy + 1.0
                        local alphaMask = (alphaCenter | alphaPart) << 0x18
                        if sqMag > 1.0 then
                            local nz = 1.0 / sqrt(sqMag)
                            local nx = min(max(dx * nz, -1.0), 1.0)
                            local ny = min(max(dy * nz, -1.0), 1.0)

                            nx = nx * xFlipNum
                            ny = ny * yFlipNum
                            nz = nz * zFlipNum

                            elm(alphaMask
                                | (trunc(nz * 127.5 + 128.0) << 0x10)
                                | (trunc(ny * 127.5 + 128.0) << 0x08)
                                | trunc(nx * 127.5 + 128.0))
                        else
                            elm(alphaMask | hexDefault)
                        end
                    else
                        elm(hexBlank)
                    end

                    writeIdx = writeIdx + 1
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
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }