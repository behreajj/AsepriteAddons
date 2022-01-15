Glyph = {}
Glyph.__index = Glyph

setmetatable(Glyph, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a new glyph from a character,
---a number representing an 8x8 matrix that
---stores the glyph's visual representation,
---and a number to drop the glyph down by
---a number of steps (for glyphs with
---descenders, such as 'g', 'p', 'q').
---@param character string
---@param matrix number
---@param drop number
---@return table
function Glyph.new(character, matrix, drop)
    local inst = setmetatable({}, Glyph)
    inst.character = character or ' '
    inst.matrix = matrix or 0
    inst.drop = drop or 0
    return inst
end

function Glyph:__eq(b)
    return self.character == b.character
end

function Glyph:__le(b)
    return string.byte(self.character)
        <= string.byte(b.character)
end

function Glyph:__lt(b)
    return string.byte(self.character)
        < string.byte(b.character)
end

function Glyph:__tostring()
    return Glyph.toJson(self)
end

---Returns a JSON string of a glyph.
---@param g table glyph
---@return string
function Glyph.toJson(g)
    return string.format(
        "{\"character\":\"%s\",\"matrix\":%d,\"drop\":%d}",
        g.character,
        g.matrix,
        g.drop)
end

return Glyph