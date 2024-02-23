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
    app.transaction("Cycle Swatch Right", function()
        local nextIdx = fgIdx + 1
        if nextIdx >= lenPalette then
            nextIdx = 0
            local alphaIdx <const> = sprite.transparentColor
            if alphaIdx == fgIdx then
                sprite.transparentColor = nextIdx
            else
                sprite.transparentColor = alphaIdx + 1
            end

            local i = lenPalette
            while i > 1 do
                i = i - 1
                palette:setColor(i, palette:getColor(i - 1))
            end
            palette:setColor(nextIdx, matchColor)
        else
            local alphaIdx <const> = sprite.transparentColor
            if alphaIdx == fgIdx then
                sprite.transparentColor = nextIdx
            elseif alphaIdx == nextIdx then
                sprite.transparentColor = fgIdx
            end

            local nextColor <const> = palette:getColor(nextIdx)
            palette:setColor(fgIdx, nextColor)
            palette:setColor(nextIdx, matchColor)
        end

        app.fgColor = matchColor
    end)
end