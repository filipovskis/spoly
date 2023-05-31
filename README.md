# 🖌 spoly
A tiny Garry's Mod library that allows you to render different shapes without jagged edges.

## Example
Smooth shapes for [Circles.lua](https://github.com/SneakySquid/Circles)

```lua
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
```

## Demonstration
The white circles are rendered through the lib.

![Image](https://i.imgur.com/PF3PdNi.png)
