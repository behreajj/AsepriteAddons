dofile("../../support/utilities.lua")
dofile("../../support/aseutilities.lua")

local hueEasing = {"FAR", "NEAR"}

local ryb = {
    Color(255, 0, 0), -- FF0000
    Color(255, 92, 0), -- FF5C00
    Color(255, 136, 0), -- FF8800
    Color(255, 173, 0), -- FFAD00
    Color(255, 209, 0), -- FFD100
    Color(255, 243, 0), -- FFF300
    Color(170, 218, 17), -- AADA11
    Color(85, 194, 34), -- 55C222
    Color(0, 169, 51), -- 00A933
    Color(9, 138, 88), -- 098A58
    Color(19, 108, 124), -- 136C7C
    Color(28, 77, 161), -- 1C4DA1
    Color(69, 58, 137), -- 453A89
    Color(110, 39, 113), -- 6E2771
    Color(150, 19, 88), -- 961358
    Color(191, 0, 64), -- BF0040
    Color(255, 0, 0) -- FF0000
}

local hues = {
    [0xFF0000FF] = 0.0,
    [0xFF005CFF] = 22.5,
    [0xFF0088FF] = 45.0,
    [0xFF00ADFF] = 67.5,
    [0xFF00D1FF] = 90.0,
    [0xFF00F3FF] = 112.5,
    [0xFF11DAAA] = 135.0,
    [0xFF22C255] = 157.5,
    [0xFF33A900] = 180.0,
    [0xFF588A09] = 202.5,
    [0xFF7C6C13] = 225.0,
    [0xFFA14D1C] = 247.5,
    [0xFF893A45] = 270.0,
    [0xFF71276E] = 292.5,
    [0xFF581396] = 315.0,
    [0xFF4000BF] = 337.5
}

local dlg = Dialog {
    title = "Palette Generator"
}

dlg:shades{
    id = "hues",
    label = "Preview:",
    colors = ryb,
    mode = "pick",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            local hue = math.tointeger(hues[ev.color.rgbaPixel])
            dlg:modify{
                id = "hueStart",
                value = hue
            }
        elseif ev.button == MouseButton.RIGHT then
            local hue = math.tointeger(hues[ev.color.rgbaPixel])
            dlg:modify{
                id = "hueEnd",
                value = hue
            }
        end
    end
}

dlg:slider{
    id = "samples",
    label = "Samples:",
    min = 1,
    max = 32,
    value = 12
}

dlg:newrow{
    always = false
}

dlg:slider{
    id = "shades",
    label = "Shades:",
    min = 1,
    max = 32,
    value = 7
}

dlg:newrow{
    always = false
}

dlg:slider{
    id = "hueStart",
    label = "Hue:",
    min = 0,
    max = 360,
    value = 0
}

dlg:slider{
    id = "hueEnd",
    min = 0,
    max = 360,
    value = 359
}

dlg:newrow{
    always = false
}

dlg:slider{
    id = "saturation",
    label = "Saturation:",
    min = 0,
    max = 100,
    value = 100
}

dlg:newrow{
    always = false
}

dlg:slider{
    id = "minLight",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = 10
}

dlg:slider{
    id = "maxLight",
    min = 0,
    max = 100,
    value = 85
}

dlg:newrow{
    always = false
}

dlg:combobox{
    id = "easingFuncHue",
    label = "Easing:",
    option = "FAR",
    options = hueEasing
}

dlg:newrow{
    always = false
}

dlg:check{
    id = "inclGray",
    label = "Include Gray:",
    selected = false
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = true,
}

dlg:newrow{
    always = false
}

dlg:button{
    id = "ok",
    text = "OK",
    focus = false,
    onclick = function()
        local args = dlg.data
        if args.ok then

            local sprite = app.activeSprite
            if sprite == nil then
                sprite = Sprite(64, 64)
            end

            local oldMode = sprite.colorMode
            app.command.ChangePixelFormat {
                format = "rgb"
            }

            local sat = args.saturation * 0.01

            local lenSamples = args.samples or 8
            local lenShades = args.shades or 8
            local inclGray = args.inclGray or (sat <= 0)
            local prependMask = args.prependMask

            local flatLen = 0
            if sat > 0 then
                flatLen = lenSamples * lenShades
            end

            local grayLen = 0
            if inclGray then
                grayLen = lenShades
            end

            local maskLen = 0
            if prependMask then
                maskLen = 1
            end

            local totLen = flatLen + grayLen + maskLen
            local palette = Palette(totLen)

            local hueStart = args.hueStart * 0.002777777777777778
            local hueEnd = args.hueEnd * 0.002777777777777778

            local hueFunc = nil
            if args.easingFuncHue == "NEAR" then
                hueFunc = function(a, b, t)
                    return Utilities.lerpAngleNear(a, b, t, 1.0)
                end
            elseif args.easingFuncHue == "FAR" then
                hueFunc = function(a, b, t)
                    return Utilities.lerpAngleFar(a, b, t, 1.0)
                end
            end

            local lMin = args.minLight * 0.01
            local lMax = args.maxLight * 0.01

            local k = 0
            if prependMask then
                k = 1
                palette:setColor(0, Color(0, 0, 0, 0))
            end

            local jToFac = 1.0
            if lenShades > 1 then
                jToFac = 1.0 / (lenShades - 1.0)
            end

            if sat > 0 then
                local iToFac = 1.0
                if lenSamples > 1 then
                    iToFac = 1.0 / (lenSamples - 1.0)
                end
                local lerpArr = AseUtilities.lerpColorArr
                local min = math.min
                local max = math.max
                for i = 1, lenSamples, 1 do
                    local iFac = (i - 1.0) * iToFac
                    local hueFac = hueFunc(hueStart, hueEnd, iFac)
                    local hex = lerpArr(ryb, hueFac)
                    local clr = Color(hex)

                    local h = clr.hslHue
                    local sold = clr.hslSaturation
                    local snew = sold * sat
                    local lold = clr.hslLightness
                    local diff = 0.5 * (0.5 - lold)
                    local a = clr.alpha

                    for j = 1, lenShades, 1 do
                        local jFac = (j - 1.0) * jToFac

                        local jFacAdj = min(1.0, max(0.0, jFac - diff))
                        -- fudge factor
                        jFacAdj = jFacAdj ^ (1.5)
                        local lnew = (1.0 - jFacAdj) * lMin + jFacAdj * lMax

                        local newclr = Color {
                            h = h,
                            s = snew,
                            l = lnew,
                            a = a
                        }
                        palette:setColor(k, newclr)
                        k = k + 1
                    end
                end
            end

            if inclGray then
                for j = 1, lenShades, 1 do
                    local t = (j - 1.0) * jToFac
                    local u = 1.0 - t
                    local lnew = u * lMin + t * lMax
                    local grayClr = Color {
                        h = 0.0,
                        s = 0.0,
                        l = lnew,
                        a = 255
                    }
                    palette:setColor(k, grayClr)
                    k = k + 1
                end
            end

            sprite:setPalette(palette)

            if oldMode == ColorMode.INDEXED then
                app.command.ChangePixelFormat {
                    format = "indexed"
                }
            elseif oldMode == ColorMode.GRAY then
                app.command.ChangePixelFormat {
                    format = "gray"
                }
            end

            app.refresh()
        else
            app.alert("Dialog arguments are invalid.")
        end
    end
}

dlg:button{
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show{
    wait = false
}
