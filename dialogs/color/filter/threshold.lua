-- https://craftofcoding.wordpress.com/2021/10/06/thresholding-algorithms-sauvola-local/

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then
    app.alert {
        title = "Error",
        text = "There is no active sprite."
    }
    return
end

local spriteSpec <const> = activeSprite.spec
local colorMode <const> = spriteSpec.colorMode
if colorMode ~= ColorMode.RGB then
    app.alert {
        title = "Error",
        text = "Only RGB color mode is supported."
    }
    return
end

local activeFrame <const> = site.frame
if not activeFrame then
    app.alert {
        title = "Error",
        text = "There is no active frame."
    }
    return
end

local activeLayer <const> = site.layer
if not activeLayer then
    app.alert {
        title = "Error",
        text = "There is no active layer."
    }
    return
end

if activeLayer.isReference then
    app.alert {
        title = "Error",
        text = "Reference layers are not supported."
    }
    return
end

if activeLayer.isGroup then
    app.alert {
        title = "Error",
        text = "Group layers are not supported."
    }
    return
end

if activeLayer.isTilemap then
    app.alert {
        title = "Error",
        text = "Tilemap layers are not supported."
    }
    return
end

local activeCel <const> = activeLayer:cel(activeFrame)
if not activeCel then
    app.alert {
        title = "Error",
        text = "There is no active cel."
    }
    return
end

local kernelStep <const> = 7
local R <const> = 128
--- "The parameter k controls the value of the threshold in the local window the higher the value of k, the lower the threshold from the local mean"
--- Range is 0.2 to 0.5
local k <const> = 0.5
local wKernel <const> = kernelStep * 2 + 1
local hKernel <const> = wKernel
local areaKernel <const> = wKernel * hKernel

local srcImg <const> = activeCel.image
local srcImgSpec <const> = srcImg.spec
local srcBytes <const> = srcImg.bytes

local wSrcImg <const> = srcImgSpec.width
local hSrcImg <const> = srcImgSpec.height
local areaSrcImg <const> = wSrcImg * hSrcImg

local strchar <const> = string.char
local strbyte <const> = string.byte

---@type string[]
local trgByteArr <const> = {}

local i = 0
while i < areaSrcImg do
    local i4 <const> = i * 4
    local rSrc <const>,
    gSrc <const>,
    bSrc <const>,
    aSrc <const> = strbyte(srcBytes, 1 + i4, 4 + i4)
    local srcIsValid <const> = aSrc > 0

    local rTrg, gTrg, bTrg, aTrg = 0, 0, 0, 0

    if srcIsValid then
        local xSrcImg <const> = (i % wSrcImg) - kernelStep
        local ySrcImg <const> = (i // wSrcImg) - kernelStep

        local validCount = 0
        local sumValue = 0
        ---@type integer[]
        local values <const> = {}

        local j = 0
        while j < areaKernel do
            local xKernel <const> = j % wKernel
            local yKernel <const> = j // wKernel
            local xNeighbor <const> = xSrcImg + xKernel
            local yNeighbor <const> = ySrcImg + yKernel

            local rNbr, gNbr, bNbr, aNbr = 0, 0, 0, 0
            if yNeighbor >= 0 and yNeighbor < hSrcImg
                and xNeighbor >= 0 and xNeighbor < wSrcImg then
                local index <const> = yNeighbor * wSrcImg + xNeighbor
                local index4 <const> = index * 4
                rNbr, gNbr, bNbr, aNbr = strbyte(srcBytes, 1 + index4, 4 + index4)
            end

            local nbrIsValid <const> = aNbr > 0
            if nbrIsValid then
                local nbrValue <const> = (rNbr * 30 + gNbr * 59 + bNbr * 11) // 100
                sumValue = sumValue + nbrValue
                validCount = validCount + 1
                values[validCount] = nbrValue
            end

            j = j + 1
        end

        local meanValue <const> = validCount > 0
            and sumValue / validCount
            or 0.0

        local deltaSum = 0
        local m = 0
        while m < validCount do
            m = m + 1
            local value <const> = values[m]
            local delta <const> = value - meanValue
            local sqDelta <const> = delta * delta
            deltaSum = deltaSum + sqDelta
        end

        local stdDev <const> = validCount > 1
            and math.sqrt(deltaSum / (validCount - 1))
            or 0.0

        local threshold <const> = meanValue * (1 + k * ((stdDev / R) - 1))
        local srcValue <const> = (rSrc * 30 + gSrc * 59 + bSrc * 11) // 100

        aTrg = aSrc
        if srcValue < threshold then
            rTrg, gTrg, bTrg = 0, 0, 0
        else
            rTrg, gTrg, bTrg = 255, 255, 255
        end
    end

    trgByteArr[1 + i4] = strchar(rTrg)
    trgByteArr[2 + i4] = strchar(gTrg)
    trgByteArr[3 + i4] = strchar(bTrg)
    trgByteArr[4 + i4] = strchar(aTrg)

    i = i + 1
end

local trgImg <const> = Image(srcImgSpec)
trgImg.bytes = table.concat(trgByteArr)
activeCel.image = trgImg
app.refresh()

-- function sauvolaTH(img, n=5, R=128 ,k=0.5)

--    dx,dy = size(img)
--    imgSize = dx * dy
--    imgN = copy(img)

--    # Calculate the radius of the neighbourhood
--    w = div((n-1),2)

--    # Process the image
--       for i = w+1:dx-w, j = w+1:dy-w
--          # Extract the neighbourhood area
--          block = img[i-w:i+w, j-w:j+w]

--          # Calculate the mean and standard deviation of the neighbourhood region
--          wBmn = mean(block)
--          wBstd = std(block)

--          # Calculate the threshold value (Eq.5)
--          wBTH = wBmn * (1 + k * ((wBstd/R) - 1))

--          # Threshold the pixel
--          if (img[i,j] < wBTH)
--             imgN[i,j] = 0
--          else
--             imgN[i,j] = 255
--       end
--    end

--     return imgN
-- end