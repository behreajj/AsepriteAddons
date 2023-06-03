dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
local responsePresets = {
    "FULL",
    "HIGHLIGHT",
    "MIDTONE",
    "SHADOW"
}

local defaults = {
    target = "ACTIVE",
    responsePreset = "FULL",
    useInvert = false,
    useSource = false,
    trimCels = true
}

---@param x number
---@return number
local function fullResponse(x)
    if x <= 0.0 then return 0.0 end
    if x >= 1.0 then return 1.0 end
    return x * x * (3.0 - (x + x))
end

---@param x number
---@return number
local function shadowResponse(x)
    -- if x <= 0.0 then return 1.0 end
    -- if x >= 0.5 then return 0.0 end
    -- return 0.5 + 0.5 * math.cos(2 * math.pi * x)
    return fullResponse(1.0 - (x + x))
end

---@param x number
---@return number
local function midResponse(x)
    -- if x <= 0.0 then return 0.0 end
    -- if x >= 1.0 then return 0.0 end
    -- return 0.5 + 0.5 * math.cos(2 * math.pi * (x - 0.5))
    return 1.0 - fullResponse(math.abs(x + x - 1.0))
end

---@param x number
---@return number
local function lightResponse(x)
    -- if x <= 0.5 then return 0.0 end
    -- if x >= 1.0 then return 1.0 end
    -- return 0.5 + 0.5 * math.cos(2 * math.pi * (1.0 - x))
    return fullResponse(x + x - 1.0)
end

local dlg = Dialog { title = "Separate Lightness" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "responsePreset",
    label = "Tone:",
    option = defaults.responsePreset,
    options = responsePresets
}

dlg:newrow { always = false }

dlg:check {
    id = "useInvert",
    label = "Flip:",
    text = "&Alpha",
    selected = defaults.useInvert
}

dlg:newrow { always = false }

dlg:check {
    id = "useSource",
    label = "Color:",
    text = "&Source",
    selected = defaults.useSource,
    onclick = function()
        local args = dlg.data
        local useSource = args.useSource --[[@as boolean]]
        dlg:modify { id = "maskColor", visible = not useSource }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "maskColor",
    -- Consider { r = 232, g = 0, b = 123 }, LCH 50, 94, 360
    color = Color { r = 255, g = 255, b = 255, a = 255 },
    visible = not defaults.useSource
}

dlg:newrow { always = false }

dlg:check {
    id = "trimCels",
    label = "Trim:",
    text = "Layer Ed&ges",
    selected = defaults.trimCels
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local spriteSpec = activeSprite.spec
        local colorMode = spriteSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local srcLayer = site.layer
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
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        -- Check for tile maps.
        local isTilemap = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset --[[@as Tileset]]
        end

        local args = dlg.data
        local target = args.target
            or defaults.target --[[@as string]]
        local responsePreset = args.responsePreset
            or defaults.responsePreset --[[@as string]]
        local useInvert = args.useInvert --[[@as boolean]]
        local useSource = args.useSource --[[@as boolean]]
        local maskColor = args.maskColor --[[@as Color]]
        local trimCels = args.trimCels --[[@as boolean]]

        local alphaIndex = spriteSpec.transparentColor
        -- local colorSpace = spriteSpec.colorSpace
        -- local srcIsGroup = srcLayer.isGroup
        local maskRgb = maskColor.blue << 0x10
            | maskColor.green << 0x08
            | maskColor.red

        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        ---@type fun(x: number): number
        local responseFunc = nil
        if responsePreset == "HIGHLIGHT" then
            responseFunc = lightResponse
        elseif responsePreset == "MIDTONE" then
            responseFunc = midResponse
        elseif responsePreset == "SHADOW" then
            responseFunc = shadowResponse
        else
            responseFunc = fullResponse
        end

        local maskLayer = nil
        app.transaction("Mask Layer", function()
            maskLayer = activeSprite:newLayer()
            maskLayer.parent = srcLayer.parent
            local strInvert = ""
            if useInvert then strInvert = ".Inverse" end
            maskLayer.name = string.format(
                "%s.Mask.%s%s",
                srcLayer.name, responsePreset, strInvert)
        end)

        -- Cache functions used in loop.
        local tilesToImage = AseUtilities.tilesToImage
        local trimAlpha = AseUtilities.trimImageAlpha
        local fromHex = Clr.fromHex
        local sRgbaToLab = Clr.sRgbToSrLab2
        local floor = math.floor
        -- local flattenGroup = AseUtilities.flattenGroup

        local lenFrames = #frames
        app.transaction("Separate Lightness", function()
            local i = 0
            while i < lenFrames do
                i = i + 1
                local srcFrame = frames[i]

                local xSrcPos = 0
                local ySrcPos = 0
                local srcImg = nil
                -- if srcIsGroup then
                --     local groupBounds = nil
                --     srcImg, groupBounds = flattenGroup(
                --         srcLayer, srcFrame,
                --         colorMode, colorSpace, alphaIndex,
                --         true, false, true, true)
                --     xSrcPos = groupBounds.x
                --     ySrcPos = groupBounds.y
                -- else
                local srcCel = srcLayer:cel(srcFrame)
                if srcCel then
                    srcImg = srcCel.image
                    if isTilemap then
                        srcImg = tilesToImage(srcImg, tileSet, colorMode)
                    end
                    local srcPos = srcCel.position
                    xSrcPos = srcPos.x
                    ySrcPos = srcPos.y
                end
                -- end

                if srcImg then
                    ---@type table<integer, integer>
                    local srcToTrg = {}
                    local srcPxItr = srcImg:pixels()
                    for pixel in srcPxItr do
                        local srcHex = pixel()
                        if not srcToTrg[srcHex] then
                            local trgHex = 0x0
                            local srcAlpha = (srcHex >> 0x18) & 0xff
                            if srcAlpha > 0 then
                                local clr = fromHex(srcHex)
                                local lab = sRgbaToLab(clr)
                                local facw = responseFunc(lab.l * 0.01)
                                local trgAlpha = floor(facw * 255.0 + 0.5)
                                if useInvert then trgAlpha = 255 - trgAlpha end
                                local trgRgb = maskRgb
                                if useSource then
                                    trgRgb = srcHex & 0x00ffffff
                                end
                                trgHex = (trgAlpha << 0x18) | trgRgb
                            end
                            srcToTrg[srcHex] = trgHex
                        end
                    end

                    local trgImg = srcImg:clone()
                    local trgPxItr = trgImg:pixels()
                    for pixel in trgPxItr do
                        pixel(srcToTrg[pixel()])
                    end

                    local xoff = 0
                    local yoff = 0
                    if trimCels then
                        trgImg, xoff, yoff = trimAlpha(trgImg, 0, alphaIndex)
                    end

                    activeSprite:newCel(
                        maskLayer, srcFrame, trgImg,
                        Point(xSrcPos + xoff, ySrcPos + yoff))
                end
            end
        end)

        -- Active layer assignment triggers a timeline update.
        app.activeLayer = maskLayer
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

dlg:show { wait = false }