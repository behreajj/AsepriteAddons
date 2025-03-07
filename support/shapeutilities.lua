dofile("./aseutilities.lua")

ShapeUtilities = {}
ShapeUtilities.__index = ShapeUtilities

setmetatable(ShapeUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Draws a curve with an image graphics context. Creates a new cel if one does
---not exist at the layer and frame. Otherwise, assigns to cel image and
---position. Returns early if the layer is a reference, group or tile map.
---@param sprite Sprite sprite
---@param curve Curve2 curve
---@param useFill boolean use fill
---@param fillClr Color fill color
---@param useStroke boolean use stroke
---@param strokeClr Color stroke color
---@param strokeWeight integer stroke weight
---@param frame Frame|integer frame
---@param layer Layer layer
---@param useAntiAlias? boolean use antialias
---@param useTrim? boolean trim image
function ShapeUtilities.drawCurve2(
    sprite, curve,
    useFill, fillClr,
    useStroke, strokeClr, strokeWeight,
    frame, layer,
    useAntiAlias, useTrim)
    -- TODO: Separate function into more granular ones,
    -- as with mesh2.

    if layer.isReference then return end
    if layer.isGroup then return end
    if layer.isTilemap then return end

    local spriteSpec <const> = sprite.spec
    local trgImg = Image(spriteSpec)

    local context <const> = trgImg.context
    if not context then return end

    local useFillVerif <const> = useFill
        and fillClr.alpha > 0
    local useStrokeVerif <const> = useStroke
        and strokeWeight > 0
        and strokeClr.alpha > 0

    local srcCel <const> = layer:cel(frame)
    local trgBlendMode = BlendMode.SRC
    if srcCel then
        local celImg <const> = srcCel.image
        local celPos <const> = srcCel.position
        trgImg:drawImage(celImg, celPos, 255, BlendMode.SRC)

        if spriteSpec.colorMode ~= ColorMode.INDEXED then
            trgBlendMode = BlendMode.NORMAL
        end
    end

    context.blendMode = trgBlendMode
    if useAntiAlias then
        context.antialias = true
    end
    if useStrokeVerif then
        context.strokeWidth = strokeWeight
    end

    local kns <const> = curve.knots
    local knsLen <const> = #kns

    local knFirst <const> = kns[1]
    local coFirst <const> = knFirst.co
    context:beginPath()
    context:moveTo(coFirst.x, coFirst.y)

    local knPrev = knFirst
    local i = 1
    while i < knsLen do
        i = i + 1
        local knCurr <const> = kns[i]
        local fhPrev <const> = knPrev.fh
        local rhCurr <const> = knCurr.rh
        local coCurr <const> = knCurr.co
        context:cubicTo(
            fhPrev.x, fhPrev.y,
            rhCurr.x, rhCurr.y,
            coCurr.x, coCurr.y)
        knPrev = knCurr
    end

    if curve.closedLoop then
        local fhPrev <const> = knPrev.fh
        local rhFirst <const> = knFirst.rh
        context:cubicTo(
            fhPrev.x, fhPrev.y,
            rhFirst.x, rhFirst.y,
            coFirst.x, coFirst.y)
        context:closePath()
    end

    if useFillVerif then
        context.color = fillClr
        context:fill()
    end

    if useStrokeVerif then
        context.color = strokeClr
        context:stroke()
    end

    local xtl, ytl = 0, 0
    if useTrim then
        trgImg, xtl, ytl = AseUtilities.trimImageAlpha(trgImg, 0,
            sprite.transparentColor, 8, 8)
    end

    if srcCel then
        srcCel.image = trgImg
        srcCel.position = Point(xtl, ytl)
    else
        sprite:newCel(layer, frame, trgImg, Point(xtl, ytl))
    end
end

---Draws a mesh with an image graphics context. Creates a new cel if one does
---not exist at the layer and frame. Otherwise, assigns to cel image and
---position. Returns early if the layer is a reference, group or tile map.
---@param sprite Sprite sprite
---@param mesh Mesh2 mesh
---@param useFill boolean use fill
---@param fillClr Color fill color
---@param useStroke boolean use stroke
---@param strokeClr Color stroke color
---@param strokeWeight integer stroke weight
---@param frame Frame|integer frame
---@param layer Layer layer
---@param useAntiAlias? boolean use antialias
---@param useTrim? boolean trim image
function ShapeUtilities.drawMesh2(
    sprite, mesh,
    useFill, fillClr,
    useStroke, strokeClr, strokeWeight,
    frame, layer,
    useAntiAlias, useTrim)
    if layer.isReference then return end
    if layer.isGroup then return end
    if layer.isTilemap then return end

    local spriteSpec <const> = sprite.spec

    local meshImage <const>,
    xtlMesh <const>,
    ytlMesh <const> = ShapeUtilities.mesh2ToImage(
        mesh, spriteSpec,
        useFill, fillClr,
        useStroke, strokeClr, strokeWeight,
        useAntiAlias, useTrim)

    local srcCel <const> = layer:cel(frame)
    if srcCel then
        local composite = Image(spriteSpec)
        local blendMode <const> = spriteSpec.colorMode ~= ColorMode.INDEXED
            and BlendMode.NORMAL
            or BlendMode.SRC
        composite:drawImage(srcCel.image, srcCel.position,
            255, BlendMode.SRC)
        composite:drawImage(meshImage, Point(xtlMesh, ytlMesh),
            255, blendMode)

        local xtlComp, ytlComp = 0, 0
        if useTrim then
            local alphaIndex <const> = spriteSpec.transparentColor
            composite, xtlComp, ytlComp = AseUtilities.trimImageAlpha(
                composite, 0, alphaIndex, 8, 8)
        end

        srcCel.image = composite
        srcCel.position = Point(xtlComp, ytlComp)
    else
        sprite:newCel(layer, frame, meshImage, Point(xtlMesh, ytlMesh))
    end
end

---Rasterizes a mesh to an image using a graphics context.
---@param mesh Mesh2 mesh
---@param refSpec ImageSpec image spec
---@param useFill boolean use fill
---@param fillClr Color fill color
---@param useStroke boolean use stroke
---@param strokeClr Color stroke color
---@param strokeWeight integer stroke weight
---@param useAntiAlias? boolean use antialias
---@param useTrim? boolean trim image
---@return Image image
---@return integer xtl
---@return integer ytl
function ShapeUtilities.mesh2ToImage(
    mesh, refSpec,
    useFill, fillClr,
    useStroke, strokeClr, strokeWeight,
    useAntiAlias, useTrim)
    local trgImg = Image(refSpec)
    local context <const> = trgImg.context
    if not context then return trgImg, 0, 0 end

    local useFillVerif <const> = useFill
        and fillClr.alpha > 0
    local useStrokeVerif <const> = useStroke
        and strokeWeight > 0
        and strokeClr.alpha > 0
    if (not useFillVerif) and (not useStrokeVerif) then
        return trgImg, 0, 0
    end

    local faces <const> = mesh.fs
    local coords <const> = mesh.vs
    local lenFaces <const> = #faces

    if useAntiAlias then context.antialias = true end
    if useStrokeVerif then context.strokeWidth = strokeWeight end

    local i = 0
    while i < lenFaces do
        i = i + 1
        local face <const> = faces[i]
        local lenFace <const> = #face

        local vtxFirst <const> = face[1]
        local coFirst <const> = coords[vtxFirst]
        context:beginPath()
        context:moveTo(coFirst.x, coFirst.y)

        local j = 1
        while j < lenFace do
            j = j + 1
            local vertex <const> = face[j]
            local coord <const> = coords[vertex]
            context:lineTo(coord.x, coord.y)
        end

        context:closePath()

        if useFillVerif then
            context.color = fillClr
            context:fill()
        end

        if useStrokeVerif then
            context.color = strokeClr
            context:stroke()
        end
    end

    -- Grayscale images need to be unpremultiplied...?
    if useAntiAlias and refSpec.colorMode == ColorMode.GRAY then
        trgImg = ShapeUtilities.unpremulGrayImage(trgImg)
    end

    local xtl, ytl = 0, 0
    if useTrim then
        local alphaIndex <const> = refSpec.transparentColor
        trgImg, xtl, ytl = AseUtilities.trimImageAlpha(trgImg, 0,
            alphaIndex, 8, 8)
    end

    return trgImg, xtl, ytl
end

---Divides all colors in a grayscale image by the alpha channel.
---@param source Image source image
---@return Image
---@nodiscard
function ShapeUtilities.unpremulGrayImage(source)
    local srcSpec <const> = source.spec
    local target <const> = Image(srcSpec)
    target.bytes = ShapeUtilities.unpremulGrayPixels(
        source.bytes, srcSpec.width, srcSpec.height)
    return target
end

---Divides all colors in a grayscale bytes array by the alpha channel.
---@param source string source bytes
---@param w integer image width
---@param h integer image height
---@return string
---@nodiscard
function ShapeUtilities.unpremulGrayPixels(source, w, h)
    ---@type string[]
    local unpremultiplied <const> = {}
    local strbyte <const> = string.byte
    local strchar <const> = string.char
    local len <const> = w * h

    local i = 0
    while i < len do
        local i2 <const> = i * 2
        local v8Src <const>, a8 <const> = strbyte(source, 1 + i2, 2 + i2)
        local v8Trg <const> = a8 > 0
            and 255 * v8Src // a8
            or 0
        unpremultiplied[1 + i2] = strchar(v8Trg)
        unpremultiplied[2 + i2] = strchar(a8)
        i = i + 1
    end

    return table.concat(unpremultiplied)
end

return ShapeUtilities