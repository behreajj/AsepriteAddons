dofile("../support/clr.lua")
dofile("../support/vec2.lua")

local dlg = Dialog { title = "Gamma Adjusted Resize" }

local scaleModes = { "PERCENT", "PIXEL" }
local algorithms = { "BILINEAR", "NEAREST", "ROT_SPRITE" }

local defaults = {
    algorithm = "NEAREST",
    scaleMode = "PERCENT",
    pxWidth = 256,
    pxHeight = 256,
    prcWidth = 1.0,
    prcHeight = 1.0
}

dlg:combobox {
    id = "algorithm",
    label = "Algorithm:",
    option = defaults.algorithm,
    options = algorithms
}

dlg:newrow { always = false }

dlg:combobox {
    id = "scaleMode",
    label = "Mode:",
    option = defaults.scaleMode,
    options = scaleModes,
    onchange = function()
        local sclmd = dlg.data.scaleMode
        local isPx = sclmd == "PIXEL"
        local isPrc = sclmd == "PERCENT"

        dlg:modify {
            id = "pxWidth",
            visible = isPx
        }
        dlg:modify {
            id = "pxHeight",
            visible = isPx
        }

        dlg:modify {
            id = "prcWidth",
            visible = isPrc
        }
        dlg:modify {
            id = "prcHeight",
            visible = isPrc
        }
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "pxWidth",
    label = "Scale PX:",
    text = string.format("%.0f", defaults.pxWidth),
    decimals = 0,
    visible = defaults.scaleMode == "PIXEL"
}

dlg:number {
    id = "pxHeight",
    text = string.format("%.0f", defaults.pxHeight),
    decimals = 0,
    visible = defaults.scaleMode == "PIXEL"
}

dlg:newrow { always = false }

dlg:number {
    id = "prcWidth",
    label = "Scale %:",
    text = string.format("%.1f",
        100.0 * defaults.prcWidth),
    decimals = 5,
    visible = defaults.scaleMode == "PERCENT"
}

dlg:number {
    id = "prcHeight",
    text = string.format("%.1f",
        100.0 * defaults.prcHeight),
    decimals = 5,
    visible = defaults.scaleMode == "PERCENT"
}

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then

                -- Change color mode to RGB.
                local oldMode = sprite.colorMode
                app.command.ChangePixelFormat { format = "rgb" }

                -- Find new scale based on scale mode.
                local scaleMode = args.scaleMode
                local scl = nil
                if scaleMode == "PIXEL" then
                    local pxWidth = args.pxWidth
                    local pxHeight = args.pxWidth
                    scl = Vec2.new(pxWidth, pxHeight)

                    -- Just in case inputs are not integers.
                    scl = Vec2.round(scl)
                else
                    local prcWidth = 0.01 * args.prcWidth
                    local prcHeight = 0.01 * args.prcHeight
                    scl = Vec2.new(
                        prcWidth * sprite.width,
                        prcHeight * sprite.height)
                    scl = Vec2.round(scl)
                end

                local oldColorSpace = sprite.colorSpace
                -- sprite:assignColorSpace(ColorSpace{ sRGB = false })
                sprite:convertColorSpace(ColorSpace{ sRGB = false })

                -- Manual standard to linear.
                -- app.transaction(function()
                --     local layers = sprite.layers
                --     local layerLen = #layers
                --     for i = 1, layerLen, 1 do
                --         local layer = layers[i]
                --         local cels = layer.cels
                --         local celLen = #cels
                --         for j = 1, celLen, 1 do
                --             local cel = cels[j]
                --             local image = cel.image
                --             local pxitr = image:pixels()
                --             for clr in pxitr do
                --                 local srgb = Clr.fromHex(clr())
                --                 local lrgb = Clr.standardToLinear(srgb)
                --                 local hex = Clr.toHex(lrgb)
                --                 clr(hex)
                --             end
                --         end
                --     end
                -- end)

                -- sprite:resize(scl.x, scl.y)

                local algorithmNative = "nearest"
                local algorithmConst = args.algorithm
                if algorithmConst == "BILINEAR" then
                    algorithmNative = "bilinear"
                elseif algorithmConst == "ROT_SPRITE" then
                    algorithmNative = "rotSprite"
                end

                app.command.SpriteSize {
                    ui = false,
                    width = scl.x,
                    height = scl.y,
                    lockRatio = false,
                    method = algorithmNative
                }

                -- Revert color space.
                -- sprite:assignColorSpace(oldColorSpace)
                sprite:convertColorSpace(oldColorSpace)

                -- Manual linear to standard.
                -- app.transaction(function()
                --     for i = 1, layerLen, 1 do
                --         local layer = layers[i]
                --         local cels = layer.cels
                --         local celLen = #cels
                --         for j = 1, celLen, 1 do
                --             local cel = cels[j]
                --             local image = cel.image
                --             local pxitr = image:pixels()
                --             for clr in pxitr do
                --                 local lrgb = Clr.fromHex(clr())
                --                 local srgb = Clr.linearToStandard(lrgb)
                --                 local hex = Clr.toHex(srgb)
                --                 clr(hex)
                --             end
                --         end
                --     end
                -- end)

                -- Revert color mode.
                if oldMode == ColorMode.INDEXED then
                    app.command.ChangePixelFormat { format = "indexed" }
                elseif oldMode == ColorMode.GRAY then
                    app.command.ChangePixelFormat { format = "gray" }
                end

                app.refresh()
            else
                app.alert("There is no active sprite.")
            end
        end
    end }

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }