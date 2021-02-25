Vec2 = {}
Vec2.__index = Vec2

function Vec2:new(x, y)
    local inst = {}
    setmetatable(inst, Vec2)
    inst.x = x or 0.0
    inst.y = y or inst.x
    return inst
end

function Vec2:__add(b)
    return Vec2:new(
            self.x + b.x,
            self.y + b.y)
end

function Vec2:__tostring()
    return string.format(
        "{ x: %.4f, y: %.4f }",
        self.x,
        self.y)
end

Mesh2 = {}
Mesh2.__index = Mesh2

function Mesh2:new(fs, vs)
    local inst = {}
    setmetatable(inst, Mesh2)
    inst.fs = fs
    inst.vs = vs
    return inst
end

function Mesh2:__tostring()
    local str = "{ fs: [ "
    
    local fsLen = #self.fs
    for i = 1, fsLen, 1 do
        local f = self.fs[i]
        local fLen = #f
        str = str .. "[ "
        for j = 1, fLen, 1 do
            str = str .. tostring(f[j])
            if j < fLen then str = str .. ", " end
        end
        str = str .. " ]"
        if i < fsLen then str = str .. ", " end
    end

    str = str .. " ], vs: [ "

    local vsLen = #self.vs
    for i = 1, vsLen, 1 do
        str = str .. tostring(self.vs[i])
        if i < vsLen then str = str .. ", " end
    end
    str = str .. " ] }"

    return str
end

Mat3 = {}
Mat3.__index = Mat3

function Mat3:new(
    m00, m01, m02,
    m10, m11, m12,
    m20, m21, m22)
    local inst = {}
    setmetatable(inst, Mat3)
    inst.m00 = m00 or 1.0
    inst.m01 = m01 or 0.0
    inst.m02 = m02 or 0.0
    inst.m10 = m10 or 0.0
    inst.m11 = m11 or 1.0
    inst.m12 = m12 or 0.0
    inst.m20 = m20 or 0.0
    inst.m21 = m21 or 0.0
    inst.m22 = m22 or 1.0
    return inst
end

function Mat3:__mul(b)
    return Mat3:new(
        self.m00 * b.m00 + self.m01 * b.m10 + self.m02 * b.m20,
        self.m00 * b.m01 + self.m01 * b.m11 + self.m02 * b.m21,
        self.m00 * b.m02 + self.m01 * b.m12 + self.m02 * b.m22,
        self.m10 * b.m00 + self.m11 * b.m10 + self.m12 * b.m20,
        self.m10 * b.m01 + self.m11 * b.m11 + self.m12 * b.m21,
        self.m10 * b.m02 + self.m11 * b.m12 + self.m12 * b.m22,
        self.m20 * b.m00 + self.m21 * b.m10 + self.m22 * b.m20,
        self.m20 * b.m01 + self.m21 * b.m11 + self.m22 * b.m21,
        self.m20 * b.m02 + self.m21 * b.m12 + self.m22 * b.m22)
end

function Mat3:__tostring()
    return string.format(
        [[{ m00: %.4f, m01: %.4f, m02: %.4f,
  m10: %.4f, m11: %.4f, m12: %.4f,
  m20: %.4f, m21: %.4f, m22: %.4f }]],
        self.m00, self.m01, self.m02,
        self.m10, self.m11, self.m12,
        self.m20, self.m21, self.m22)
end

function Mat3:fromRotZ(radians)
    return Mat3:fromRotZInternal(
        math.cos(radians),
        math.sin(radians))
end

function Mat3:fromRotZInternal(cosa, sina)
    return Mat3:new(
        cosa, -sina, 0.0,
        sina,  cosa, 0.0,
         0.0,   0.0, 1.0)
end

function Mat3:fromScale(width, depth)
    local w = 1.0
    if width and width ~= 0.0 then
        w = width
    end

    local d = w
    if depth and depth ~= 0.0 then
        d = depth
    end

    return Mat3:new(
          w, 0.0, 0.0,
        0.0,   d, 0.0,
        0.0, 0.0, 1.0)
end

function Mat3:fromTranslation(x, y)
    return Mat3:new(
        1.0, 0.0,   x,
        0.0, 1.0,   y,
        0.0, 0.0, 1.0)
end

function Mat3:mulPoint(a, b)
    local w = a.m20 * b.x + a.m21 * b.y + a.m22
    if w ~= 0.0 then
        local wInv = 1.0 / w
        return Vec2:new(
            (a.m00 * b.x + a.m01 * b.y + a.m02) * wInv,
            (a.m10 * b.x + a.m11 * b.y + a.m12) * wInv)
    else
        return Vec2:new(0.0, 0.0)
    end
end

function drawMesh(m, strokeClr, brsh, cel, layer)
    local fs = m.fs
    local vs = m.vs

    local fsLen = #fs
    local vsLen = #vs

    for i = 1, fsLen, 1 do
        local f = fs[i]
        local fLen = #f
        
        local vPrev = vs[f[fLen]]
        local ptPrev = Point(vPrev.x, vPrev.y)
        
        for j = 1, fLen, 1 do
            local vert = f[j]
            local v = vs[vert]
            local pt = Point(v.x, v.y)
            
            app.useTool{
                tool="line",
                color=strokeClr,
                brush=brsh,
                points={ptPrev, pt},
                cel=cel,
                layer=layer,
                freehandAlgorithm=1}
            
            vPrev = v
            ptPrev = pt
        end
    end
end

local defaults = {
    cols = 8,
    rows = 8,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    strokeWeight = 1,
    strokeClr = Color(32, 32, 32, 255),
    useFill = true,
    fillClr = Color(255, 245, 215, 255)
}

local dlg = Dialog{
    title="Isometric Grid"}

dlg:slider{
    id="cols",
    label="Columns: ",
    min=2,
    max=32,
    value=defaults.cols}

dlg:slider{
    id="rows",
    label="Rows: ",
    min=2,
    max=32,
    value=defaults.rows}

dlg:number{
    id="scale",
    label="Scale: ",
    text=string.format("%.2f", defaults.scale),
    decimals=5}

dlg:number{
    id="xOrigin",
    label="Origin X: ",
    text=string.format("%.2f", defaults.xOrigin),
    decimals=5}

dlg:number{
    id="yOrigin",
    label="Origin Y: ",
    text=string.format("%.2f", defaults.yOrigin),
    decimals=5}

dlg:slider{
    id="strokeWeight",
    label="Stroke Weight:",
    min=1,
    max=64,
    value=defaults.strokeWeight}

dlg:color{
    id="strokeClr",
    label="Stroke Color: ",
    color=defaults.strokeClr}

dlg:button{
    id="ok",
    text="OK",
    onclick=function()
        local args = dlg.data

        -- Create vertical positions in [-0.5, 0.5].
        local rval = args.rows
        local rvaln1 = rval - 1
        local iToStep = 1.0 / rval
        local ys = {}
        for i = 0, rval, 1 do
            table.insert(ys, i * iToStep - 0.5)
        end

        -- Create horizontal positions in [-0.5, 0.5].
        local cval = args.cols
        local cvaln1 = cval - 1
        local cvalp1 = cval + 1
        local jToStep = 1.0 / cval
        local xs = {}
        for j = 0, cval, 1 do
            table.insert(xs, j * jToStep - 0.5)
        end

        local sclval = args.scale
        if sclval < 2.0 then
            sclval = 2.0
        end

        -- Composite matrices.
        local t = Mat3:fromTranslation(
            args.xOrigin,
            args.yOrigin)
        local s = Mat3:fromScale(
            sclval * 0.7071067811865475,
            sclval * 0.35355339059327373)
        local r = Mat3:fromRotZ(math.rad(45))
        local m = t * s * r

        -- Combine xs and ys into points.
        local vs = {}
        for i = 0, rval, 1 do
            for j = 0, cval, 1 do
                local v = Vec2:new(xs[1 + j], ys[1 + i])
                local vp = Mat3:mulPoint(m, v)
                table.insert(vs, vp)
            end
        end

        local fs = {}
        for i = 0, rvaln1, 1 do
            local noff0 = i * cvalp1
            local noff1 = noff0 + cvalp1
            for j = 0, cvaln1, 1 do
                local n00 = noff0 + j
                local n10 = n00 + 1
                local n01 = noff1  + j
                local n11 = n01 + 1

                -- Create face loop.
                local f = {}

                -- Insert vertices into loop.
                table.insert(f, 1 + n00)
                table.insert(f, 1 + n10)
                table.insert(f, 1 + n11)
                table.insert(f, 1 + n01)

                -- Insert face loop into faces.
                table.insert(fs, f)
            end
        end

        local mesh = Mesh2:new(fs, vs)
        
        -- function drawMesh(m, clr, brsh, cel, layer)
        local brsh = Brush(args.strokeWeight)
        local sprite = app.activeSprite
        local layer = sprite:newLayer()
        layer.name = cval .. "x" .. rval .. "Grid"
        local cel = sprite:newCel(layer, 1)

        drawMesh(mesh, args.strokeClr, brsh, cel, layer)
        app.refresh()
    end}

dlg:button{
    id="cancel",
    text="CANCEL",
    onclick=function()
        dlg:close()
    end}

dlg:show{wait=false}