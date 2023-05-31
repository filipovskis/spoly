--[[
MIT License

Copyright (c) 2023 Aleksandrs Filipovskis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

spoly = spoly or {}
spoly.materials = spoly.materials or {}

local spoly = spoly
local materials = spoly.materials

local SIZE = 2048
-- MATERIAL_RT_DEPTH_SEPARATE makes stencils possible to work
local RT = GetRenderTargetEx ('spoly_rt2', SIZE, SIZE, 0, MATERIAL_RT_DEPTH_SEPARATE, bit.band(16, 1024), 0, IMAGE_FORMAT_DEFAULT)
local CAPTURE_DATA = {
    x = 0,
    y = 0,
    w = SIZE,
    h = SIZE,
    format = 'png',
    alpha = true
}

file.CreateDir('spoly')

--[[------------------------------
Either render.PushFilterMin and render.PushFilterMag don't work with materials created with Lua
Idk what shader parameter is missing, I couldn't find it even by comparing materials' KeyValues
--------------------------------]]
function spoly.Generate(id, funcDraw)
    assert(isstring(id), Format('bad argument #1 to \'spoly.Generate\' (expected string, got %s)', type(id)))
    assert(isfunction(funcDraw), Format('bad argument #2 to \'spoly.Generate\' (expected function, got %s)', type(funcDraw)))

    local path = 'spoly/' .. id .. '.png'

    render.PushRenderTarget(RT)
    
        render.Clear(0, 0, 0, 0)
        
        cam.Start2D()
            surface.SetDrawColor(color_white)
            draw.NoTexture()
            pcall(funcDraw, SIZE, SIZE)
        cam.End2D()

        local content = render.Capture(CAPTURE_DATA)

        file.Delete(path)
        file.Write(path, content)
    
    render.PopRenderTarget()

    materials[id] = Material('data/' .. path, 'mips')

    return function(x, y, w, h, color)
        spoly.Draw(id, x, y, w, h, color)
    end
end

do
    local SetDrawColor = surface.SetDrawColor
    local SetMaterial = surface.SetMaterial
    local DrawTexturedRect = surface.DrawTexturedRect

    local PushFilterMag = render.PushFilterMag
    local PushFilterMin = render.PushFilterMin
    local PopFilterMag = render.PopFilterMag
    local PopFilterMin = render.PopFilterMin

    -- calling this really often so trying to optimize as much as possible
    function spoly.Draw(id, x, y, w, h, color)
        local material = materials[id]
    
        if (color) then
            SetDrawColor(color)
        end
    
        SetMaterial(material)
        
        PushFilterMag(TEXFILTER.ANISOTROPIC)
        PushFilterMin(TEXFILTER.ANISOTROPIC)
    
        DrawTexturedRect(x, y, w, h)
    
        PopFilterMag()
        PopFilterMin()
    end
end

--[[------------------------------
Sometimes materials cannot be overriden, so change the name if you want to edit it's content
--------------------------------]]
--[[
    spoly.DrawCircle = spoly.Generate('circle', function(w, h)
        local x0, y0 = w * .5, h * .5
        local radius = h * .5
        local circle = Circles.New(CIRCLE_FILLED, radius, x0, y0)
        
        poly()
    end)

    spoly.DrawOutlinedCircle = spoly.Generate('circle_outline_256', function(w, h)
        local x0, y0 = w * .5, h * .5
        local radius = h * .5
        local thickness = 256
        local circle = Circles.New(CIRCLE_OUTLINED, radius, x0, y0, thickness)
        
        circle()
    end)

    hook.Add('HUDPaint', 'Test', function()
        surface.SetDrawColor(color_white)

        local y = 512
        local x = 512
        local space = ScreenScale(1)

        local amount = 8
        local multiplier = 16
        local maxSize = multiplier * amount

        for i = 1, amount do
            local size = multiplier * i

            spoly.DrawOutlinedCircle(x, y + maxSize * .5 - size * .5, size, size)

            x = x + size + space
        end

        y = y + maxSize + (space * 10)
        x = 512

        for i = 1, amount do
            local size = multiplier * i

            spoly.DrawCircle(x, y + maxSize * .5 - size * .5, size, size)

            x = x + size + space
        end
    end)
]]