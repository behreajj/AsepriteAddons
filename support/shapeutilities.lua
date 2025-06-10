dofile("./aseutilities.lua")

ShapeUtilities = {}
ShapeUtilities.__index = ShapeUtilities

setmetatable(ShapeUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Draws an array of curves with an image graphics context.
---Creates a new cel if one does not exist at the layer and frame.
---Otherwise, assigns to cel image and position.
---Returns early if the layer is a reference, group or tile map.
---@param sprite Sprite sprite
---@param curves Curve2[] curve
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
    sprite, curves,
    useFill, fillClr,
    useStroke, strokeClr, strokeWeight,
    frame, layer,
    useAntiAlias, useTrim)
    if layer.isReference then return end
    if layer.isGroup then return end
    if layer.isTilemap then return end

    local spriteSpec <const> = sprite.spec

    local imgCurve <const>,
    xtlCurve <const>,
    ytlCurve <const> = ShapeUtilities.rasterizeCurve2(
        curves, spriteSpec,
        useFill, fillClr,
        useStroke, strokeClr, strokeWeight,
        useAntiAlias, useTrim)

    local srcCel <const> = layer:cel(frame)
    if srcCel then
        local composite = Image(spriteSpec)
        composite:drawImage(srcCel.image, srcCel.position,
            255, BlendMode.SRC)
        composite:drawImage(imgCurve, Point(xtlCurve, ytlCurve),
            255, BlendMode.NORMAL)

        local xtlComp, ytlComp = 0, 0
        if useTrim then
            local alphaIndex <const> = spriteSpec.transparentColor
            composite, xtlComp, ytlComp = AseUtilities.trimImageAlpha(
                composite, 0, alphaIndex, 8, 8)
        end

        srcCel.image = composite
        srcCel.position = Point(xtlComp, ytlComp)
    else
        sprite:newCel(layer, frame, imgCurve, Point(xtlCurve, ytlCurve))
    end
end

---Draws an ellipse with an image graphics context.
---@param context GraphicsContext canvas
---@param xc number center x
---@param yc number center y
---@param w number radius x
---@param h number radius y
---@param useFill boolean use fill
---@param fillClr Color fill color
---@param useStroke boolean use stroke
---@param strokeClr Color stroke color
---@param strokeWeight integer stroke weight
---@param useAntiAlias? boolean use antialias
function ShapeUtilities.drawEllipse(
    context,
    xc, yc, w, h,
    useFill, fillClr,
    useStroke, strokeClr, strokeWeight,
    useAntiAlias)
    local useFillVerif <const> = useFill
        and fillClr.alpha > 0
    local useStrokeVerif <const> = useStroke
        and strokeWeight > 0
        and strokeClr.alpha > 0
    if (not useFillVerif) and (not useStrokeVerif) then
        return
    end

    local kw <const> = 0.5522847498307936 * w
    local kh <const> = 0.5522847498307936 * h

    local right <const> = xc + w
    local left <const> = xc - w
    local top <const> = yc + h
    local bottom <const> = yc - h

    if useAntiAlias then context.antialias = true end
    if useStrokeVerif then context.strokeWidth = strokeWeight end

    context:beginPath()
    context:moveTo(right, yc)
    context:cubicTo(right, yc + kh, xc + kw, top, xc, top)
    context:cubicTo(xc - kw, top, left, yc + kh, left, yc)
    context:cubicTo(left, yc - kh, xc - kw, bottom, xc, bottom)
    context:cubicTo(xc + kw, bottom, right, yc - kh, right, yc)
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

---Draws a mesh with an image graphics context.
---Creates a new cel if one does not exist at the layer and frame.
---Otherwise, assigns to cel image and position.
---Returns early if the layer is a reference, group or tile map.
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

    local imgMesh <const>,
    xtlMesh <const>,
    ytlMesh <const> = ShapeUtilities.rasterizeMesh2(
        mesh, spriteSpec,
        useFill, fillClr,
        useStroke, strokeClr, strokeWeight,
        useAntiAlias, useTrim)

    local srcCel <const> = layer:cel(frame)
    if srcCel then
        local composite = Image(spriteSpec)
        composite:drawImage(srcCel.image, srcCel.position,
            255, BlendMode.SRC)
        composite:drawImage(imgMesh, Point(xtlMesh, ytlMesh),
            255, BlendMode.NORMAL)

        local xtlComp, ytlComp = 0, 0
        if useTrim then
            local alphaIndex <const> = spriteSpec.transparentColor
            composite, xtlComp, ytlComp = AseUtilities.trimImageAlpha(
                composite, 0, alphaIndex, 8, 8)
        end

        srcCel.image = composite
        srcCel.position = Point(xtlComp, ytlComp)
    else
        sprite:newCel(layer, frame, imgMesh, Point(xtlMesh, ytlMesh))
    end
end

---Rasterizes an array of curves to an image using a graphics context.
---@param curves Curve2[] curve array
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
function ShapeUtilities.rasterizeCurve2(
    curves, refSpec,
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

    if useAntiAlias then context.antialias = true end
    if useStrokeVerif then context.strokeWidth = strokeWeight end

    local lenCurves <const> = #curves
    local i = 0
    while i < lenCurves do
        i = i + 1
        local curve <const> = curves[i]
        local kns <const> = curve.knots
        local knsLen <const> = #kns

        local knFirst <const> = kns[1]
        local coFirst <const> = knFirst.co
        context:beginPath()
        context:moveTo(coFirst.x, coFirst.y)

        local knPrev = knFirst
        local j = 1
        while j < knsLen do
            j = j + 1
            local knCurr <const> = kns[j]
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
    end

    local xtl, ytl = 0, 0
    if useTrim then
        local alphaIndex <const> = refSpec.transparentColor
        trgImg, xtl, ytl = AseUtilities.trimImageAlpha(trgImg, 0,
            alphaIndex, 8, 8)
    end

    if useAntiAlias and refSpec.colorMode == ColorMode.GRAY then
        trgImg = ShapeUtilities.unpremulGrayImage(trgImg)
    end

    return trgImg, xtl, ytl
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
function ShapeUtilities.rasterizeMesh2(
    mesh, refSpec,
    useFill, fillClr,
    useStroke, strokeClr, strokeWeight,
    useAntiAlias, useTrim)
    -- Might not be necessary to make a method that accepts an array
    -- of meshes, since a mesh is already an array of faces.

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

        local coFirst <const> = coords[face[1]]
        context:beginPath()
        context:moveTo(coFirst.x, coFirst.y)

        local j = 1
        while j < lenFace do
            j = j + 1
            local coord <const> = coords[face[j]]
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

    local xtl, ytl = 0, 0
    if useTrim then
        local alphaIndex <const> = refSpec.transparentColor
        trgImg, xtl, ytl = AseUtilities.trimImageAlpha(trgImg, 0,
            alphaIndex, 8, 8)
    end

    if useAntiAlias and refSpec.colorMode == ColorMode.GRAY then
        trgImg = ShapeUtilities.unpremulGrayImage(trgImg)
    end

    return trgImg, xtl, ytl
end

---Divides all colors in a grayscale image by the alpha channel.
---@param source Image source image
---@return Image
---@nodiscard
function ShapeUtilities.unpremulGrayImage(source)
    local target <const> = Image(source.spec)
    target.bytes = ShapeUtilities.unpremulGrayPixels(source.bytes)
    return target
end

---Divides all colors in a grayscale bytes array by the alpha channel.
---@param source string source bytes
---@return string
---@nodiscard
function ShapeUtilities.unpremulGrayPixels(source)
    ---@type string[]
    local unpremultiplied <const> = {}
    local strbyte <const> = string.byte
    local strchar <const> = string.char
    local len <const> = #source // 2

    local i = 0
    while i < len do
        local i2 <const> = i + i
        local v8 <const>, a8 <const> = strbyte(source, 1 + i2, 2 + i2)
        local upv8 <const> = a8 > 0 and 255 * v8 // a8 or 0
        unpremultiplied[1 + i2] = strchar(upv8 < 255 and upv8 or 255)
        unpremultiplied[2 + i2] = strchar(a8)
        i = i + 1
    end

    return table.concat(unpremultiplied)
end

return ShapeUtilities