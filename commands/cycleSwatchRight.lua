dofile("../support/aseutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end
local frame <const> = site.frame
if not frame then return end

-- Preserving fore and background color interferes with range.
local palette <const> = AseUtilities.getPalette(frame, sprite.palettes)

local range <const> = app.range
local rangeIsValid <const> = range.sprite == sprite
local rangeClrIdcs <const> = range.colors
local lenRangeClrIdcs <const> = #rangeClrIdcs

if rangeIsValid and lenRangeClrIdcs > 1 then
    ---@type Color[]
    local rangeColors <const> = {}
    local i = 0
    while i < lenRangeClrIdcs do
        i = i + 1
        rangeColors[i] = palette:getColor(rangeClrIdcs[i])
    end

    app.transaction("Cycle Swatches Right", function()
        local shift <const> = -1
        local j = 0
        while j < lenRangeClrIdcs do
            j = j + 1
            local clrIdx <const> = rangeClrIdcs[j]
            local shiftedIdx <const> = 1 + (shift + j - 1) % lenRangeClrIdcs
            palette:setColor(clrIdx, rangeColors[shiftedIdx])
        end
    end)
else
    local fgColor <const> = app.fgColor
    local fgIdx <const> = fgColor.index
    local matchColor <const> = palette:getColor(fgIdx)
    if fgColor.red == matchColor.red
        and fgColor.green == matchColor.green
        and fgColor.blue == matchColor.blue
        and fgColor.alpha == matchColor.alpha then
        local lenPalette <const> = #palette

        app.transaction("Cycle Swatch Right", function()
            local nextIdx = fgIdx + 1
            if nextIdx >= lenPalette then
                nextIdx = 0
                local i = lenPalette
                while i > 1 do
                    i = i - 1
                    palette:setColor(i, palette:getColor(i - 1))
                end
                palette:setColor(nextIdx, matchColor)
            else
                local nextColor <const> = palette:getColor(nextIdx)
                palette:setColor(fgIdx, nextColor)
                palette:setColor(nextIdx, matchColor)
            end

            app.fgColor = matchColor
        end)
    end
end