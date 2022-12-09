dofile("../../support/aseutilities.lua")

local invPowPrev = {
    Color { r = 0, g = 0, b = 0 },
    Color { r = 98, g = 98, b = 98 },
    Color { r = 136, g = 136, b = 136 },
    Color { r = 164, g = 164, b = 164 },
    Color { r = 187, g = 187, b = 187 },
    Color { r = 207, g = 207, b = 207 },
    Color { r = 224, g = 224, b = 224 },
    Color { r = 240, g = 240, b = 240 },
    Color { r = 255, g = 255, b = 255 }
}

local linearPrev = {
    Color { r = 0, g = 0, b = 0 },
    Color { r = 31, g = 31, b = 31 },
    Color { r = 63, g = 63, b = 63 },
    Color { r = 95, g = 95, b = 95 },
    Color { r = 127, g = 127, b = 127 },
    Color { r = 159, g = 159, b = 159 },
    Color { r = 191, g = 191, b = 191 },
    Color { r = 223, g = 223, b = 223 },
    Color { r = 255, g = 255, b = 255 }
}

local powerPrev = {
    Color { r = 0, g = 0, b = 0 },
    Color { r = 3, g = 3, b = 3 },
    Color { r = 13, g = 13, b = 13 },
    Color { r = 29, g = 29, b = 29 },
    Color { r = 54, g = 54, b = 54 },
    Color { r = 88, g = 88, b = 88 },
    Color { r = 133, g = 133, b = 133 },
    Color { r = 188, g = 188, b = 188 },
    Color { r = 255, g = 255, b = 255 }
}

local directions = { "LINEAR_TO_STANDARD", "STANDARD_TO_LINEAR" }
local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "ACTIVE",
    direction = "STANDARD_TO_LINEAR",
    pullFocus = false
}

local dlg = Dialog { title = "sRGB Conversion" }

dlg:shades {
    id = "invPowPrev",
    label = "1.0 / 2.4:",
    colors = invPowPrev,
    mode = "pick"
}

dlg:newrow { always = false }

dlg:shades {
    id = "linearPrev",
    label = "1.0:",
    colors = linearPrev,
    mode = "pick"
}

dlg:newrow { always = false }

dlg:shades {
    id = "powerPrev",
    label = "2.4:",
    colors = powerPrev,
    mode = "pick"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "direction",
    label = "Direction:",
    option = defaults.direction,
    options = directions
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local args = dlg.data
        local target = args.target or defaults.target
        local direction = args.direction or defaults.target

        local lut = {}
        if direction == "LINEAR_TO_STANDARD" then
            lut = Utilities.LTS_LUT
        else
            lut = Utilities.STL_LUT
        end

        local colorMode = activeSprite.colorMode
        if colorMode == ColorMode.INDEXED then
            app.transaction(function()
                local palettes = activeSprite.palettes
                local lenPalettes = #palettes
                local i = 0
                while i < lenPalettes do i = i + 1
                    local palette = palettes[i]
                    local lenPaletten1 = #palette - 1
                    local j = -1
                    while j < lenPaletten1 do j = j + 1
                        local origin = palette:getColor(j)
                        palette:setColor(j, Color {
                            r = lut[1 + origin.red],
                            g = lut[1 + origin.green],
                            b = lut[1 + origin.blue],
                            a = origin.alpha
                        })
                    end
                end
            end)
            app.refresh()
            return
        end

        -- Does not handle 1.3 tile maps.
        local cels = {}
        if target == "ACTIVE" then
            local activeCel = app.activeCel
            if activeCel then
                cels[1] = activeCel
            end
        elseif target == "RANGE" then
            local images = app.range.images
            local lenImgs = #images
            local i = 0
            while i < lenImgs do i = i + 1
                cels[i] = images[i].cel
            end
        else
            local frIdcs = {}
            local lenFrames = #activeSprite.frames
            local i = 0
            while i < lenFrames do i = i + 1
                frIdcs[i] = i
            end

            local appRange = app.range
            appRange.frames = frIdcs

            local images = appRange.images
            local lenImgs = #images
            local j = 0
            while j < lenImgs do j = j + 1
                cels[j] = images[j].cel
            end

            appRange:clear()
        end

        -- Image must be cloned and reassigned to create a
        -- transaction that can be undone.
        app.transaction(function()
            local lenCels = #cels
            if colorMode == ColorMode.GRAY then
                local i = 0
                while i < lenCels do i = i + 1
                    local cel = cels[i]
                    if cel then
                        local trgImg = cel.image:clone()
                        local pxItr = trgImg:pixels()
                        for elm in pxItr do
                            local h = elm()
                            local a = h >> 0x08 & 0xff
                            if a > 0 then
                                elm(a << 0x08 | lut[1 + (h & 0xff)])
                            else
                                elm(0x0)
                            end
                        end
                        cel.image = trgImg
                    end
                end
            else
                local i = 0
                while i < lenCels do i = i + 1
                    local cel = cels[i]
                    if cel then
                        local trgImg = cel.image:clone()
                        local pxItr = trgImg:pixels()
                        for elm in pxItr do
                            local h = elm()
                            local a = h >> 0x18 & 0xff
                            if a > 0 then
                                elm(a << 0x18
                                    | lut[1 + (h >> 0x10 & 0xff)] << 0x10
                                    | lut[1 + (h >> 0x08 & 0xff)] << 0x08
                                    | lut[1 + (h & 0xff)])
                            else
                                elm(0x0)
                            end
                        end
                        cel.image = trgImg
                    end
                end
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

dlg:show { wait = false }