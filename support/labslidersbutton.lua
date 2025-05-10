dofile("./aseutilities.lua")
dofile("./canvasutilities.lua")

LabSliderButtons = {}
LabSliderButtons.__index = LabSliderButtons

setmetatable(LabSliderButtons, {
    -- TODO: This might be better off incorporated into
    -- CanvasUtilities.... and then when you're done
    -- implementing it, delete the spectrum widget that
    -- had been used on new sprite plus.
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Default background checker color.
LabSliderButtons.CHECKER_COLOR_A = 0xff808080

---Default background checker color.
LabSliderButtons.CHECKER_COLOR_B = 0xffcacaca

---Background checker height for transparent colors.
LabSliderButtons.CHECKER_HEIGHT = 8

---Background checker width for transparent colors.
LabSliderButtons.CHECKER_WIDTH = 8

---Color for text display.
LabSliderButtons.TEXT_COLOR = 0xff181818

---Color for text drop shadow.
LabSliderButtons.TEXT_SHADOW = 0xffe7e7e7

---Creates a child dialog with LCH sliders.
---@param dlgParent Dialog the parent dialog
---@param wButton integer color button width
---@param hButton integer color button height
---@param labelButton string color button label
---@param abgr32Initial integer initial button color
---@param textDisplayInitial "WEB_HEX"|"LCH"|"RGB" button text display
---@return Dialog dlgSliders child dialog
---@return table active variables table
function LabSliderButtons.dialogWidgets(
    dlgParent,
    wButton,
    hButton,
    labelButton,
    abgr32Initial,
    textDisplayInitial)
    -- TODO: Implement.
    -- You'd have to organize this so that both
    -- the in depth color picker and a simplified
    -- child packer can access slider widgets.
    --
    -- This will also have to show a consistent
    -- color button in the parent dialog.
    --
    -- Unfortunately a color button canvas might
    -- have to be different from a color preview
    -- on the main LCH.

    local srgbInitial <const> = Rgb.fromHexAbgr32(abgr32Initial)
    local lchInitial <const> = ColorUtilities.sRgbToSrLch(srgbInitial)

    local active <const> = {
        l = lchInitial.l,
        c = lchInitial.c,
        h = lchInitial.h,
        a = lchInitial.a,
        textDisplay = textDisplayInitial,
    }

    -- region Child Dialog

    local dlgChild <const> = Dialog {
        title = "LCH Color Picker",
        parent = dlgParent
    }

    dlgChild:newrow { always = false }

    dlgChild:button {
        id = "cancel",
        text = "&CANCEL",
        focus = false,
        onclick = function()
            dlgChild:close()
        end
    }

    -- endregion

    dlgParent:canvas {
        id = "labColorButton",
        label = labelButton or "Color:",
        width = wButton,
        height = hButton,
        vexpand = false,
        focus = false,
        onpaint = function(event)
            -- Get and set canvas variables.
            local ctx <const> = event.context
            local wCanvas <const> = ctx.width
            local hCanvas <const> = ctx.height
            ctx.antialias = true
            ctx.blendMode = BlendMode.NORMAL

            -- Unpack active.
            local l <const> = active.l
            local c <const> = active.c
            local h <const> = active.h
            local a <const> = active.a
            local textDisplay <const> = active.textDisplay

            local srgb <const> = ColorUtilities.srLchTosRgb(l, c, h, a)
            local abgr32 <const> = Rgb.toHex(srgb)
            local abgr32Opaque <const> = 0xff000000 | abgr32
            local wABar <const> = math.floor(a * wCanvas + 0.5)
            local hABar <const> = 5

            ctx.color = AseUtilities.hexToAseColor(abgr32Opaque)
            ctx:fillRect(Rectangle(0, 0, wCanvas, hCanvas))
            ctx.color = Color { r = 24, g = 24, b = 24, alpha = 255 }
            ctx:fillRect(Rectangle(0, hCanvas - hABar, wCanvas, hABar))
            ctx.color = Color { r = 255, g = 245, b = 215, alpha = 255 }
            ctx:fillRect(Rectangle(0, hCanvas - hABar, wABar, hABar))

            -- Flip text colors for bright colors.
            local textColor = LabSliderButtons.TEXT_COLOR
            local textShadow = LabSliderButtons.TEXT_SHADOW
            if l < 54.0 then
                textShadow, textColor = textColor, textShadow
            end

            local str = ""
            if textDisplay == "WEB_HEX" then
                str = '#' .. Rgb.toHexWeb(srgb)
            elseif textDisplay == "LCH" then
                str = string.format(
                    "L:%03d C:%03d H:%03d A:%03d",
                    math.floor(l + 0.5),
                    math.floor(c + 0.5),
                    math.floor(h * 360.0 + 0.5),
                    math.floor(a * 255.0 + 0.5))
            elseif textDisplay == "RGB" then
                str = string.format(
                    "R:%03d G:%03d B:%03d A:%03d",
                    math.floor(srgb.r * 255.0 + 0.5),
                    math.floor(srgb.g * 255.0 + 0.5),
                    math.floor(srgb.b * 255.0 + 0.5),
                    math.floor(srgb.a * 255.0 + 0.5))
            end

            local strMeasure <const> = ctx:measureText(str)
            local xCenterButton <const> = wCanvas * 0.5
            local yCenterButton <const> = (hCanvas - hABar) * 0.5
            local wStrHalf <const> = strMeasure.width * 0.5
            local hStr <const> = strMeasure.height
            local xTextCenter <const> = math.floor(xCenterButton - wStrHalf)
            local yTextCenter <const> = math.floor(yCenterButton - hStr)

            -- Use Aseprite color as an intermediary so as
            -- to support all color modes.
            ctx.color = AseUtilities.hexToAseColor(textShadow)
            ctx:fillText(str, xTextCenter + 1, yTextCenter + 1)
            ctx.color = AseUtilities.hexToAseColor(textColor)
            ctx:fillText(str, xTextCenter, yTextCenter)
        end,
        onmouseup = function(event)
            dlgChild:show {
                autoscrollbars = false,
                hand = true,
                wait = true,
            }
        end
    }

    dlgParent:newrow { always = false }

    return dlgChild, active
end

return LabSliderButtons