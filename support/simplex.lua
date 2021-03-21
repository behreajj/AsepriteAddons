dofile("./vec2.lua")

Simplex = {}
Simplex.__index = Simplex

setmetatable(Simplex, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Generates simplex noise.
---@return table
function Simplex.new()
    local inst = setmetatable({}, Simplex)
    return inst
end

---A look up table for the gradient function.
Simplex.grad2lut = {
    Vec2.new(-1.0, -1.0), -- 1
    Vec2.new( 1.0,  0.0), -- 2
    Vec2.new(-1.0,  0.0), -- 3
    Vec2.new( 1.0,  1.0), -- 4
    Vec2.new(-1.0,  1.0), -- 5
    Vec2.new( 0.0, -1.0), -- 6
    Vec2.new( 0.0,  1.0), -- 7
    Vec2.new( 1.0, -1.0)  -- 8
}

---A constant for simplex evaluation.
Simplex.zero2 = Vec2.new(0.0, 0.0)

---Evaluates two real numbers and seed.
---Returns a signed factor.
---@param x number x coordinate
---@param y number y coordinate
---@param seed integer seed
---@return number
function Simplex.eval2(x, y, seed)
    -- 0.5 * (math.sqrt(3.0) - 1.0)
    local f2 = 0.3660254037844386
    -- (3.0 - math.sqrt(3.0)) / 6.0
    local g2 = 0.21132486540518713
    -- 1.0 / math.sqrt(3.0)
    local n221 = 0.5773502691896258
    local scale2 = 64.0

    local s = (x + y) * f2

    local xs = x + s
    local i = math.tointeger(xs)
    local xstrunc = i
    if xs < xstrunc then i = i - 1 end

    local ys = y + s
    local j = math.tointeger(ys)
    local ystrunc = j
    if ys < ystrunc then j = j - 1 end

    local t = (i + j) * g2
    local x0 = x - (i - t)
    local y0 = y - (j - t)

    local i1 = 0
    local j1 = 0
    if x0 > y0 then i1 = 1 else j1 = 1 end

    local n0 = 0.0
    local t20 = 0.0
    local t40 = 0.0
    local h0 = Simplex.zero2
    local t0 = 0.5 - (x0 * x0 + y0 * y0)
    if t0 >= 0.0 then
        h0 = Simplex.gradient2(i, j, seed)
        t20 = t0 * t0
        t40 = t20 * t20
        n0 = h0.x * x0 + h0.y * y0
    end

    local n1 = 0.0
    local t21 = 0.0
    local t41 = 0.0
    local h1 = Simplex.zero2
    local x1 = x0 - i1 + g2
    local y1 = y0 - j1 + g2
    local t1 = 0.5 - ( x1 * x1 + y1 * y1 )
    if t1 >= 0.0 then
        h1 = Simplex.gradient2(i + i1, j + j1, seed)
        t21 = t1 * t1
        t41 = t21 * t21
        n1 = h1.x * x1 + h1.y * y1
    end

    local n2 = 0.0
    local t22 = 0.0
    local t42 = 0.0
    local h2 = Simplex.zero2
    local x2 = x0 - n221
    local y2 = y0 - n221
    local t2 = 0.5 - ( x2 * x2 + y2 * y2 )
    if t2 >= 0.0 then
        h2 = Simplex.gradient2(i + 1, j + 1, seed)
        t22 = t2 * t2
        t42 = t22 * t22
        n2 = h2.x * x2 + h2.y * y2
    end

    return scale2 * (t40 * n0 + t41 * n1 + t42 * n2)
end

---Fractal Brownian Motion.
---For a given number of octaves,
---sums the output of a noise function.
---Per each iteration, the output is
---multiplied by the amplitude;
---amplitude is multiplied by gain;
---frequency is multiplied by lacunarity.
---@param vx number x coordinate
---@param vy number y coordinate
---@param seed integer seed
---@param octaves integer octaves
---@param lacunarity number lacunarity
---@param gain number gain
function Simplex.fbm2(
    vx, vy, seed, octaves,
    lacunarity, gain)

    local freq = 1.0
    local amp = 0.5
    local vinx = 0.0
    local viny = 0.0
    local sum = 0.0

    local oct = octaves or 8
    local lac = lacunarity or 1.0
    local gn = gain or 1.0

    for i = 0, oct, 1 do
        vinx = vx * freq
        viny = vy * freq

        sum = sum + amp *
            Simplex.eval2(vinx, viny, seed)

        freq = freq * lac
        amp = amp * gn
    end

    return sum
end

---Converts three integers to an array index, then
---returns a Vec2 from a look up table.
---@param i integer first integer
---@param j integer second integer
---@param seed integer seed
---@return table
function Simplex.gradient2(i, j, seed)
    return Simplex.grad2lut[1 +
        (Simplex.hash(i, j, seed) & 0x7)]
end

---Performs a series of bit-shifting operations
---to create a hash. Original author: Bob Jenkins.
---@param a integer first integer
---@param b integer second integer
---@param c integer third integer
---@return integer
function Simplex.hash(a, b, c)
    c = c ~ b
    c = c - (b << 0xe | b >> 0x20 - 0xe)
    a = a ~ c
    a = a - (c << 0xb | c >> 0x20 - 0xb)
    b = b ~ a
    b = b - (a << 0x19 | a >> 0x20 - 0x19)
    c = c ~ b
    c = c - (b << 0x10 | b >> 0x20 - 0x10)
    a = a ~ c
    a = a - (c << 0x4 | c >> 0x20 - 0x4)
    b = b ~ a
    b = b - (a << 0xe | a >> 0x20 - 0xe)
    c = c ~ b
    c = c - (b << 0x18 | b >> 0x20 - 0x18)
    return c
end

---Takes a vector input; returns a noise vector.
---@param v table vector
---@param seed integer seed
---@return table
function Simplex.noise2(v, seed)
    local st = 0.7071067811865475 * Vec2.mag(v)
    return Vec2.new(
        Simplex.eval2(v.x + st, v.y, seed),
        Simplex.eval2(v.x, v.y + st, seed))
end

return Simplex