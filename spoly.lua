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


local STATUS_IDLE = 0
local STATUS_BUSY = 1

spoly = spoly or {}
spoly.materials = spoly.materials or {}
spoly.queue = spoly.queue or {}
spoly.status = STATUS_IDLE

local spoly = spoly
local materials = spoly.materials
local queue = spoly.queue
local queued = {}

local SIZE = 2048
-- MATERIAL_RT_DEPTH_SEPARATE makes stencils possible to work
local RT = GetRenderTargetEx ('onyx_spoly_rt', SIZE, SIZE, 0, MATERIAL_RT_DEPTH_SEPARATE, bit.band(16, 1024), 0, IMAGE_FORMAT_DEFAULT)
local CAPTURE_DATA = {
    x = 0,
    y = 0,
    w = SIZE,
    h = SIZE,
    format = 'png',
    alpha = true
}

file.CreateDir('spoly')

do
    local colorTag = Color(92, 192, 254)
    local colorError = Color(254, 92, 92)
    local tag = '[SPoly] '

    function spoly.Print(text, ...)
        MsgC(colorTag, tag, color_white, string.format(text, ...), '\n')
    end

    function spoly.PrintError(text, ...)
        MsgC(colorTag, tag, colorError, '[ERROR] ', color_white, string.format(text, ...), '\n')
    end
end

--[[------------------------------
Either render.PushFilterMin and render.PushFilterMag don't work with materials created with Lua
Idk what shader parameter is missing, I couldn't find it even by comparing materials' KeyValues
--------------------------------]]
function spoly.Render(id, funcDraw)
    local path = 'spoly/' .. id .. '.png'
    local start = SysTime()

    spoly.status = STATUS_BUSY

    render.PushRenderTarget(RT)
    
        render.Clear(0, 0, 0, 0)
        
        cam.Start2D()
            surface.SetDrawColor(color_white)
            draw.NoTexture()
            local success, errorText = pcall(funcDraw, SIZE, SIZE)
        cam.End2D()

        local content = render.Capture(CAPTURE_DATA)

        file.Delete(path)
        file.Write(path, content)
    
    render.PopRenderTarget()

    materials[id] = Material('data/' .. path, 'mips')

    spoly.status = STATUS_IDLE

    local endtime = SysTime()
    local delta = tostring(math.Round(endtime - start, 3))

    if (not success) then
        spoly.PrintError('Failed to render \'%s\', error text: %s', id, errorText)
    else
        spoly.Print('Rendered \'%s\' in %ss', id, delta)
    end

    return function(x, y, w, h, color)
        spoly.Draw(id, x, y, w, h, color)
    end
end

function spoly.Generate(id, funcDraw)
    assert(isstring(id), Format('bad argument #1 to \'spoly.Generate\' (expected string, got %s)', type(id)))
    assert(isfunction(funcDraw), Format('bad argument #2 to \'spoly.Generate\' (expected function, got %s)', type(funcDraw)))
    
    if (materials[id]) then return end
    if (queued[id]) then return end

    local path = 'spoly/' .. id .. '.png'
    if (file.Exists(path, 'DATA')) then
        materials[id] = Material('data/' .. path, 'mips')
        return
    end

    queued[id] = true

    table.insert(queue, {
        id = id,
        funcDraw = funcDraw
    })
end

do
    local thinkRate = 1 / 10
    local nextThink = 0
    hook.Add('Think', 'spoly.QueueController', function()
        if (spoly.status == STATUS_IDLE and queue[1] and nextThink <= CurTime()) then
            nextThink = CurTime() + thinkRate
    
            local data = table.remove(queue, 1)
    
            spoly.Render(data.id, data.funcDraw)
        end
    end)
end

do
    local SetDrawColor = surface.SetDrawColor
    local SetMaterial = surface.SetMaterial
    local DrawTexturedRect = surface.DrawTexturedRect
    local DrawTexturedRectRotated = surface.DrawTexturedRectRotated

    local PushFilterMag = render.PushFilterMag
    local PushFilterMin = render.PushFilterMin
    local PopFilterMag = render.PopFilterMag
    local PopFilterMin = render.PopFilterMin

    -- calling this really often so trying to optimize as much as possible
    function spoly.Draw(id, x, y, w, h, color)
        local material = materials[id]
        if (not material) then return end
    
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

    function spoly.DrawRotated(id, x, y, w, h, rotation, color)
        local material = materials[id]
    
        if (color) then
            SetDrawColor(color)
        end
    
        SetMaterial(material)
        
        PushFilterMag(TEXFILTER.ANISOTROPIC)
        PushFilterMin(TEXFILTER.ANISOTROPIC)
    
        DrawTexturedRectRotated(x, y, w, h, rotation)
    
        PopFilterMag()
        PopFilterMin()
    end
end

--[[------------------------------
Sometimes materials cannot be overriden, so change the name if you want to edit it's content
--------------------------------]]
--[[
    -- Example with Circles.lua (https://github.com/SneakySquid/Circles)

    spoly.DrawCircle = spoly.Generate('circle', function(w, h)
        local x0, y0 = w * .5, h * .5
        local radius = h * .5
        local circle = Circles.New(CIRCLE_FILLED, radius, x0, y0)
        
        circle()
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
