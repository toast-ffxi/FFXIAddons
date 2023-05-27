bar = {}

function bar.new(barSettings)
	b = {}
	b.width = barSettings.width
	b.font = barSettings.font
	b.fontSize = barSettings.fontSize
	b.showDist = barSettings.showDist
	b.color = barSettings.color
	b.ratName = nil
	bar.init(b)
	bar.setPos(b, barSettings.posX, barSettings.posY)
	return b
end

function bar.init(b)
	b.capLeft = images.new({
		texture = {path=windower.addon_path..'img/cap_left.png', fit=true},
		pos = {x=0, y=0},
		visible = true,
		size = {width=6, height=12},
		draggable = false })
	b.bg = images.new({
		texture = {path=windower.addon_path..'img/bg.png', fit=true},
		pos = {x=0, y=0},
		visible = true,
		color = {alpha=b.color.alpha, red=b.color.red, green=b.color.green, blue=b.color.blue},
		size = {width=b.width, height=12},
		draggable = false })
	b.capRight = images.new({
		texture = {path=windower.addon_path..'img/cap_right.png', fit=true},
		pos = {x=0, y=0},
		visible = true,
		size = {width=6, height=12},
		draggable = false })
	b.fill = images.new({
		texture = {path=windower.addon_path..'img/fill.png', fit=true},
		pos = {x=0, y=0},
		visible = true,
		color = {alpha=b.color.alpha, red=b.color.red, green=b.color.green, blue=b.color.blue},
		size = {width=b.width, height=12},
		draggable = false })
	b.ratTxt = texts.new('${rat|(Rat)}', {
		pos = {x=0, y=0},
		text = {size=b.fontSize+2, font=b.font, stroke={width=1, alpha=255, red=50, green=50, blue=50}},
		flags = {bold=true, italic=true, draggable=false},
		bg = {visible=false} })
	b.nameTxt = texts.new('${name|(Name)} ${hpp|(100)}', {
		pos = {x=0, y=0},
		text = {size=b.fontSize, font=b.font, stroke={width=1, alpha=255, red=50, green=50, blue=50}},
		flags = {bold=true, italic=true, draggable=false},
		bg = {visible=false} })
	b.distTxt = texts.new('${distance|(0.0)}\'', {
		pos = {x=0, y=0},
		text = {size=b.fontSize*0.8, font=b.font, stroke={width=1, alpha=255, red=50, green=50, blue=50}},
		flags = {bold=true, draggable=false},
		bg = {visible=false} })
end

function bar.show(b)
	if not b then return end
	if b.showDist then b.distTxt:show() end
	if b.ratName then b.ratTxt:show() end
	b.nameTxt:show()
	b.capLeft:show()
	b.bg:show()
	b.capRight:show()
	b.fill:show()
end

function bar.hide(b)
	if not b then return end
	b.distTxt:hide()
	b.ratTxt:hide()
	b.nameTxt:hide()
	b.capLeft:hide()
	b.bg:hide()
	b.capRight:hide()
	b.fill:hide()
end	

function bar.setBarPct(b, val)
	if not b then return end
	b.fill:width(val * b.width)
	b.bg:width(b.width)
end

function bar.setTextColor(b, color)
	if not b then return end
	b.nameTxt:color(color.red, color.green, color.blue)
	b.distTxt:color(color.red, color.green, color.blue)
end

function bar.setPos(b, x, y)
	if not b then return end
	b.x = x
	b.y = y
	b.capLeft:pos(x, y)
	b.bg:pos(x+6, y)
	b.fill:pos(x+6, y)
	b.capRight:pos(x+6+b.width, y)
	b.nameTxt:pos(x+8, y-math.floor(b.fontSize/2))
	b.distTxt:pos(x+b.width+13, y)
	b.ratTxt:pos(x+8, y- math.floor(b.fontSize*2))
end

function bar.setRat(b, ratName)
	if not b then return end
	b.ratName = ratName
	if ratName then
		b.ratTxt.rat = ratName
	else
		b.ratTxt.rat = ""
	end
end

function bar.getID(b)
	if not b then return end
	return b.id
end

function bar.update(b, name, hpp, dist, id)
	if not b then return end
	b.nameTxt.name = name .. ":"
	b.nameTxt.hpp = hpp .. "%"
	bar.setBarPct(b, hpp/100)
	b.distTxt.distance = string.format('%.1f', dist)
	b.id = id
end

function bar.destroy(b)
	if not b then return end
	b.distTxt:destroy()
	b.nameTxt:destroy()
	b.ratTxt:destroy()
	b.capLeft:destroy()
	b.bg:destroy()
	b.fill:destroy()
	b.capRight:destroy()
end

function bar.hover(b, x, y)
	if not b then return end
	return b.bg:hover(x, y) or
	b.fill:hover(x, y) or
	b.capLeft:hover(x, y) or
	b.capRight:hover(x, y) or
	b.nameTxt:hover(x, y) or
	b.distTxt:hover(x, y) or
	b.ratTxt:hover(x, y)
end
