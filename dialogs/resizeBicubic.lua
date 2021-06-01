local dlg = Dialog { title = "Resize Cel Bicubic" }

dlg:number {
    id = "pxWidth",
    label = "Width Px:",
    text = string.format("%.0f", 64),
    decimals = 0
}

dlg:number {
    id = "pxHeight",
    label = "Height Px:",
    text = string.format("%.0f", 64),
    decimals = 0
}

dlg:slider {
    id = "prcWidth",
    label = "Width %:",
    min = 25,
    max = 200,
    value = 100,
    visible = false
}

dlg:slider {
    id = "prcHeight",
    label = "Height %:",
    min = 25,
    max = 200,
    value = 100,
    visible = false
}

dlg:combobox {
    id = "units",
    label = "Units:",
    option = "PIXEL",
    options = { "PERCENT", "PIXEL" },
    onchange = function()
        local unitType = dlg.data.units
        dlg:modify {
            id = "pxWidth",
            visible = unitType == "PIXEL"
        }
        dlg:modify {
            id = "pxHeight",
            visible = unitType == "PIXEL"
        }

        dlg:modify {
            id = "prcWidth",
            visible = unitType == "PERCENT"
        }
        dlg:modify {
            id = "prcHeight",
            visible = unitType == "PERCENT"
        }
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then
                local cel = app.activeCel
                if cel then
                    local srcImg = cel.image
                    if srcImg then

                        -- Cache global functions to locals.
                        local max = math.max
                        local min = math.min
                        local trunc = math.tointeger                        
                        
                        -- Find source and destination dimensions.
                        local sw = srcImg.width
                        local sh = srcImg.height
                        local dw = args.pxWidth or sw
                        local dh = args.pxHeight or sh

                        local unitType = args.units
                        if unitType == "PERCENT" then
                            dw = trunc(0.5 + sw * 0.01 * args.prcWidth)
                            dh = trunc(0.5 + sh * 0.01 * args.prcHeight)
                        else
                            dw = max(2, dw)
                            dh = max(2, dh)
                        end

                        -- Return early if no resize is needed.
                        if dw == sw and dh == sh then return end
        
                        local oldMode = sprite.colorMode
                        app.command.ChangePixelFormat { format = "rgb" }

                        -- Acquire pixels from source image.
                        local srcpx = {}
                        local srcpxitr = srcImg:pixels()
                        local srcidx = 1
                        for elm in srcpxitr do
                            srcpx[srcidx] = elm()
                            srcidx = srcidx + 1
                        end

                        local frameSize = 4
                        local chnlCount = 4
                        local frame = { 0, 0, 0, 0 }

                        -- Adjust resize by a fudge factor.
                        local bias = 0.00405
                        local tx = sw / (dw * (1.0 + bias))
                        local ty = sh / (dh * (1.0 + bias))

                        local newPxlLen = dw * dh
                        local clrs = {}
                        local len2 = frameSize * chnlCount
                        local len3 = dw * len2
                        local len4 = dh * len3

                        for k = 0, len4, 1 do
                            local g = k // len3
                            local m = k - g * len3
                            local h = m // len2
                            local n = m - h * len2
                            local j = n % frameSize

                            -- Row.
                            local y = trunc(ty * g)
                            local dy = ty * (g - bias) - y
                            local dysq = dy * dy

                            -- Column.
                            local x = trunc(tx * h)
                            local dx = tx * (h - bias) - x
                            local dxsq = dx * dx

                            local a0 = 0
                            local d0 = 0
                            local d2 = 0
                            local d3 = 0

                            local z = y - 1 + j
                            if z > -1 and z < sh then
                                local i8 = 8 * (n // frameSize)
                                local x1 = x - 1
                                local x2 = x + 1
                                local x3 = x + 2
                                local zw = z * sw

                                if x > -1 and x < sw then
                                    a0 = srcpx[1 + zw + x] >> i8 & 0xff
                                end

                                if x1 > -1 and x1 < sw then
                                    d0 = srcpx[1 + zw + x1] >> i8 & 0xff
                                end

                                if x2 > -1 and x2 < sw then
                                    d2 = srcpx[1 + zw + x2] >> i8 & 0xff
                                end

                                if x3 > -1 and x3 < sw then
                                    d3 = srcpx[1 + zw + x3] >> i8 & 0xff
                                end
                            end

                            d0 = d0 - a0
                            d2 = d2 - a0
                            d3 = d3 - a0

                            local d36 = d3 / 6.0;
                            local a1 = -d0 / 3.0 + d2 - d36
                            local a2 = 0.5 * (d0 + d2)
                            local a3 = -d0 / 6.0 - 0.5 * d2 + d36

                            frame[1 + j] = max(0, min(255,
                                a0 + trunc(a1 * dx
                                         + a2 * dxsq
                                         + a3 * (dx * dxsq))))

                            a0 = frame[2]
                            d0 = frame[1] - a0
                            d2 = frame[3] - a0
                            d3 = frame[4] - a0

                            d36 = d3 / 6.0;
                            a1 = -d0 / 3.0 + d2 - d36
                            a2 = 0.5 * (d0 + d2)
                            a3 = -d0 / 6.0 - 0.5 * d2 + d36

                            clrs[1 + (k // frameSize)] = max(0, min(255,
                                a0 + trunc(a1 * dy
                                         + a2 * dysq
                                         + a3 * (dy * dysq))))

                            k = k + 1
                        end

                        -- Set target image pixels.
                        local trgImg = Image(dw, dh)
                        local trgpxitr = trgImg:pixels()
                        local h = 0
                        for elm in trgpxitr do
                            local hex = clrs[h + 1]
                                      | clrs[h + 2] << 0x08
                                      | clrs[h + 3] << 0x10
                                      | clrs[h + 4] << 0x18
                            elm(hex)
                            h = h + 4
                        end

                        app.transaction(function()
                            -- Set cel image to target image.
                            cel.image = trgImg

                            -- Center the cel.
                            local celPos = cel.position
                            local xCenter = celPos.x + sw / 2
                            local yCenter = celPos.y + sh / 2
                            cel.position = Point(
                                xCenter - dw / 2,
                                yCenter - dh / 2)
                        end)

                        if oldMode == ColorMode.INDEXED then
                            app.command.ChangePixelFormat { format = "indexed" }
                        elseif oldMode == ColorMode.GRAY then
                            app.command.ChangePixelFormat { format = "gray" }
                        end
        
                        app.refresh()
                    else
                        app.alert("The cel has no image.");
                    end
                else
                    app.alert("There is no active cel.");
                end
            else
                app.alert("There is no active sprite.");
            end
        else
            app.alert("Dialog arguments are invalid.")
        end
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }