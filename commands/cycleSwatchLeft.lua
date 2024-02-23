dofile("../support/aseutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end
local frame <const> = site.frame
if not frame then return end

local palette <const> = AseUtilities.getPalette(frame, sprite.palettes)
local lenPalette <const> = #palette

local fgColor <const> = app.fgColor
local fgIdx <const> = fgColor.index

local matchColor <const> = palette:getColor(fgIdx)

if fgColor.red == matchColor.red
    and fgColor.green == matchColor.green
    and fgColor.blue == matchColor.blue
    and fgColor.alpha == matchColor.alpha then
    app.transaction("Cycle Swatch Left", function()
        local prevIdx = fgIdx - 1
        if prevIdx < 0 then
            prevIdx = lenPalette - 1
            local alphaIdx <const> = sprite.transparentColor
            if alphaIdx == fgIdx then
                sprite.transparentColor = prevIdx
            else
                sprite.transparentColor = alphaIdx - 1
            end

            local i = -1
            while i < lenPalette - 2 do
                i = i + 1
                palette:setColor(i, palette:getColor(i + 1))
            end
            palette:setColor(prevIdx, matchColor)
        else
            local alphaIdx <const> = sprite.transparentColor
            if alphaIdx == fgIdx then
                sprite.transparentColor = prevIdx
            elseif alphaIdx == prevIdx then
                sprite.transparentColor = fgIdx
            end

            local prevColor <const> = palette:getColor(prevIdx)
            palette:setColor(fgIdx, prevColor)
            palette:setColor(prevIdx, matchColor)
        end

        app.fgColor = matchColor
    end)
end