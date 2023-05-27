--[[Copyright © 2023, Toast
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of <addon name> nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Toast BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.--]]

_addon.name = 'AutoTargetAssist'
_addon.author = 'Toast'
_addon.version = '1.0.1'
_addon.commands = {'ata', 'autotargetassist'}

require('luau')
require('chat')
packets = require('packets')
images = require('images')
texts = require('texts')

require('bar')

local defaults = {}
defaults.maxDist = 21
defaults.mobHPFilter = 'highest'
defaults.petFilter = true
defaults.preferSimilar = false
defaults.blacklist = ""
defaults.enmityBar = {
	posX = 100, posY = 450, width = 200,
	color = {alpha=255, red=90, green=180, blue=90},
	font = 'Arial', fontSize = 10, show = true,
	showDist = true, maxCount = 20,
	stack = 'down', stackPad = 20}
defaults.ratBar = {
	posX = 400, posY = 250, width = 200,
	color = {alpha=255, red=90, green=180, blue=90},
	font = 'Arial', fontSize = 10, showDist = true}

local settings = config.load(defaults)
local blacklist = S{}
if settings.blacklist:length() > 0 then
	blacklist = S(string.lower(settings.blacklist):split(", "))
end

local targetingOn = true
local engaged = false
local myTarget = windower.ffxi.get_mob_by_target('t')
local lastSelectedID = nil
local previousSelectedIDs = T{}
local previousSelectedNames = T{}
local lockTargetResponse = nil
local player = windower.ffxi.get_player()
local playerZone = windower.ffxi.get_info().zone
local partyMembers = T{}
local partyMemberNames = S{}
local partyMemebersInZone
local partyPets = T{}
local enmityList = T{}
local enmityListNames = T{}
local enmityBars = T{}
local enmityListPage = 1
local ratBar = nil
local ratName = nil
local ratTarget = nil
local actionCategories = S{1, 2, 3, 4, 6, 11, 13, 15}
local affirmatives = S{"on", "true", "t", "yes", "y"}
local negatives = S{"off", "false", "f", "no", "n"}
local untargetableEntities = S{"zisurru", "malicious spire", "poison mist"}
local state = {}
state.setup = false
state.cs = false
state.debug = false
local timestamp = 0

local debugInfo = T{}
debugInfo.enemyCount = 0
debugInfo.lastName = ""
debugInfo.lastID = nil
debugInfo.startTime = nil
debugInfo.selectTime = nil
debugInfo.switchTime = nil

debugBox = texts.new('Enemy Count: ${enemyCount}\nLast: ${lastName}\nLastID: ${lastID}\nSelect: ${selectTime}\nSwitch: ${switchTime}',
				{pos = {x=0, y=300},
				text = {size=10, font="arial", red=255, green=255, blue=255, alpha=255},
				flags = {draggable=true},
				bg = {visible=true, red=0, green=0, blue=0, alpha=150}})
debugBox:hide()


windower.register_event('addon command', function (...)
	local args	= T{...}:map(string.lower)
	if affirmatives:contains(args[1]) then
		targetingOn = true
		addonMessage("targeting: on")
	elseif negatives:contains(args[1]) then
		targetingOn = false
		addonMessage("targeting: off")
	elseif S{"distance", "dist", "d"}:contains(args[1]) then
		local distNum = tonumber(args[2])
		if distNum then 
			settings.maxDist = distNum
		end
		addonMessage("maximum distance: " .. tostring(settings.maxDist))
	elseif S{"hpfilter", "hpf"}:contains(args[1]) then
		local filterValue = args[2]
		if S{"highest", "high", "h"}:contains(filterValue) then
			settings.mobHPFilter = 'highest'
		elseif S{"lowest", "low", "l"}:contains(filterValue) then
			settings.mobHPFilter = 'lowest'
		elseif S{"none", "n"}:contains(filterValue) then
			settings.mobHPFilter = 'none'
		end
		addonMessage("mobHPFilter: " .. settings.mobHPFilter)
	elseif S{"petfilter", "pet", "pf"}:contains(args[1]) then
		local filterValue = args[2]
		if affirmatives:contains(filterValue) then
			settings.petFilter = true
		elseif negatives:contains(filterValue) then
			settings.petFilter = false
		else 
			if settings.petFilter == true then settings.petFilter = false 
			else settings.petFilter = true end
		end
		addonMessage("petFilter: " .. tostring(settings.petFilter))
	elseif S{"prefersimilar", "sim", "ps"}:contains(args[1]) then
		local filterValue = args[2]
		if affirmatives:contains(filterValue) then
			settings.preferSimilar = true
		elseif negatives:contains(filterValue) then
			settings.preferSimilar = false
		else 
			if settings.preferSimilar == true then settings.preferSimilar = false
			else settings.preferSimilar = true end
		end
		addonMessage("preferSimilar: " .. tostring(settings.preferSimilar))
	elseif S{"blacklist", "bl"}:contains(args[1]) then
		local blCommand = args[2]
		if args[2] == "clear" then
			blacklist = S{}
			addonMessage("blacklist cleared")
		elseif args[2] and args[3] then
			local subArgs = args:slice(3, args:length())
			if S{"add", "a"}:contains(blCommand) then
				addToBlacklist(subArgs)
			elseif S{"remove", "r"}:contains(blCommand) then
				removeFromBlacklist(subArgs)
			end
		else
			addonMessage("blacklist: " .. tostring(blacklist))
		end
	elseif S{"clear", "c"}:contains(args[1]) then
		clearEnmityList()
		addonMessage("enmity list cleared")
	elseif args[1] == "save" then
		local blistStr = blacklist:tostring():stripchars('{}')
		settings.blacklist = blistStr
		config.save(settings, player.name)
		addonMessage("settings saved")
	elseif args[1] == "settings" then
		addonMessage("settings -- \n Maximum distance: " .. tostring(settings.maxDist) .. "\n Mob HP filter: " .. settings.mobHPFilter .. "\n Pet filter: " .. tostring(settings.petFilter) .. "\n Prefer similar: " .. tostring(settings.preferSimilar))
	elseif args[1] == "barsettings" then
		addonMessage("enmityBar settings -- \n Position X: " .. tostring(settings.enmityBar.posX) .. " Y: " .. tostring(settings.enmityBar.posY) .. "\n Width: " .. tostring(settings.enmityBar.width) .. "\n Visible: " .. tostring(settings.enmityBar.show) .. "\n Distance: " .. tostring(settings.enmityBar.showDist) .. "\n Max count: " .. tostring(settings.enmityBar.maxCount) .. "\n Direction: " .. settings.enmityBar.stack)
	elseif args[1] == "ratbarsettings" then
		addonMessage("ratBar settings -- \n Position X: " .. tostring(settings.ratBar.posX) .. " Y: " .. tostring(settings.ratBar.posY) .. "\n Width: " .. tostring(settings.ratBar.width) .. "\n Distance: " .. tostring(settings.ratBar.showDist))
	elseif args[1] == "bar" then
		if S{"x", "posx"}:contains(args[2]) then 
			local xnum = tonumber(args[3])
			if xnum then settings.enmityBar.posX = xnum end
			addonMessage("bar X: " .. settings.enmityBar.posX)
		end
		if S{"y", "posy"}:contains(args[2]) then
			local ynum = tonumber(args[3])
			if ynum then settings.enmityBar.posY = ynum end
			addonMessage("bar Y: " .. settings.enmityBar.posY)
		end
		if S{"w", "width"}:contains(args[2]) then
			local wnum = tonumber(args[3])
			if wnum then settings.enmityBar.width = wnum end
			addonMessage("bar width: " .. settings.enmityBar.width)
		end
		if S{"s", "show", "vis", "visible"}:contains(args[2]) then
			local val = args[3]
			if affirmatives:contains(val) then
				settings.enmityBar.show = true
			elseif negatives:contains(val) then
				settings.enmityBar.show = false
			else
				if settings.enmityBar.show == true then settings.enmityBar.show = false
				else settings.enmityBar.show = true end
			end
			addonMessage("bar visible: " .. tostring(settings.enmityBar.show))
		end
		if S{"d", "dist", "distance"}:contains(args[2]) then
			local val = args[3]
			if affirmatives:contains(val) then
				settings.enmityBar.showDist = true
			elseif negatives:contains(val) then
				settings.enmityBar.showDist = false
			else
				if settings.enmityBar.showDist == true then settings.enmityBar.showDist = false
				else settings.enmityBar.showDist = true end
			end
			addonMessage("bar show distance: " .. tostring(settings.enmityBar.showDist))
		end
		if S{"max", "c", "count", "maxcount"}:contains(args[2]) then
			local countNum = tonumber(args[3])
			if countNum then settings.enmityBar.maxCount = countNum end
			addonMessage("bar maxCount: " .. settings.enmityBar.maxCount)
		end
		if S{"dir", "direction"}:contains(args[2]) then
			local direction = tostring(args[3])
			if S{"u", "up"}:contains(direction) then
				settings.enmityBar.stack = "up"
			elseif S{"d", "down"}:contains(direciton) then
				settings.enmityBar.stack = "down"
			else
				if settings.enmityBar.stack == "up" then settings.enmityBar.stack = "down"
				else settings.enmityBar.stack = "up" end
			end
			addonMessage("bar direction: " .. settings.enmityBar.stack)
		end
		initEnmityBars()
	elseif args[1] == "rat" then
		if S{"x", "posx"}:contains(args[2]) then 
			local xnum = tonumber(args[3])
			if xnum then settings.ratBar.posX = xnum end
			addonMessage("ratBar X: " .. settings.ratBar.posX)
		end
		if S{"y", "posy"}:contains(args[2]) then
			local ynum = tonumber(args[3])
			if ynum then settings.ratBar.posY = ynum end
			addonMessage("ratBar Y: " .. settings.ratBar.posY)
		end
		if S{"w", "width"}:contains(args[2]) then
			local wnum = tonumber(args[3])
			if wnum then settings.ratBar.width = wnum end
			addonMessage("ratBar width: " .. settings.ratBar.width)
		end
		if S{"d", "dist", "distance"}:contains(args[2]) then
			local val = args[3]
			if affirmatives:contains(val) then
				settings.ratBar.showDist = true
			elseif negatives:contains(val) then
				settings.ratBar.showDist = false
			else
				if settings.ratBar.showDist == true then settings.ratBar.showDist = false
				else settings.ratBar.showDist = true end
			end
			addonMessage("ratBar show distance: " .. tostring(settings.enmityBar.showDist))
		end
		if args[2] == "set" then
			local name = findPartStrMatch(partyMemberNames, args[3])
			if name then
				ratName = name
				addonMessage("raid assist target: " .. name:ucfirst())
			else
				addonMessage("raid assist target out of range or not in party")
			end
		end
		if negatives:contains(args[2]) or not args[2] then
			if ratBar then 
				ratName = nil
				addonMessage("raid assist target removed")
			end
		end
		initRatBar()
	elseif S{"assist", "arat"}:contains(args[1]) then
		ratAssist()
	elseif args[1] == "listnextpage" then
		listPageNext()
	elseif args[1] == "listprevpage" then
		listPagePrev()
	elseif args[1] == "setup" then
		if state.setup then state.setup = false
		else state.setup = true end
		addonMessage("bar setup: " .. tostring(state.setup))
	elseif args[1] == "next" then
		if playerCharmed() then return end
		debugInfo.startTime = os.clock()
		determineNextBestTarget("next")
	elseif args[1] == "prev" then
		if playerCharmed() then return end
		debugInfo.startTime = os.clock()
		targetPrevious()
	elseif args[1] == "nextdiff" then
		if playerCharmed() then return end
		debugInfo.startTime = os.clock()
		determineNextBestTarget("nextdiff")
	elseif args[1] == "debug" then
		if state.debug then state.debug = false
		else state.debug = true end
	elseif args[1] == "help" or args[1] == nil then
		local helptext = [[Auto Target Assist - command list
		1. on | off -- Turns targeting on or off. Default is on.
		2. d | distance [number] -- Sets the maximum auto-targeting distance.
		3. hpf | hpfilter <h | high | highest, l | low | lowest, n | none> --
		     Sets hp filter value. Highest targets monsters with the highest 
		     remaining hp first. Lowest targets monsters with the lowest 
		     remaining hp first. None targets based on distance from you.
		4. pf | pet | petfilter <t | true, f | false> -- Sets pet filter value.
		     If true, enemy pets will not be tracked.
		5. ps | sim | prefersimilar <t | true, f | false> -- Sets prefer similar
		     target. If true will prioritize targeting enemies with exact matching 
		     names, then partially matching names.
		6. bl | blacklist <a | add, r | remove, clear> <t | [enemy name]> --
		     Blacklist feature prevents mobs on the blacklist from being tracked. 
		     Invoking with no other params will echo your current blacklist to chat. 
		     The t parameter will attempt to use the name of your current target. 
		     Otherwise typing the enemy name will add or remove it from the blacklist.
		7. c | clear -- Clears the current enmity list.
		8. save -- Saves all your settings for the current character.
		9. settings -- Displays your current settings.
		10. barsettings -- Displays your current settings for the visual enemy bars.
		11. ratbarsettings -- Displays your current settings for the raid assist target.
		12. bar <x [num] , y [num], width [num], visible <t | f>, dist <t | f>, 
		     max [num], dir <up | down>> -- Changes settings for the visible enemy bars.
		13. rat <x [num], y [num], width [num], dist <t | f>, set [name]> -- Changes
		     settings for the raid assist target bar. Call with no parameters to remove.
		14. setup -- Toggles setup mode for visible enemy bars and raid assist bar.
		15. assist | arat -- Will attempt to switch your target to whatever the
		     raid assist target last acted upon.
		16. next -- Selects the next best target according to your settings.
		17. prev -- Selects the previous target chosen by the addon.
		18. nextdiff -- Selects the next best target according to your settings 
		     that has a different name than your current target.
		19. listnextpage -- Scrolls visible enmity list if there are more tracked
		     targets than your maxCount setting.
		20. listprevpage -- Scrolls visible enmity list back to previous pages.
		21. debug -- Toggles additional information in a text box.]]
		for _, line in ipairs(helptext:split('\n')) do
			windower.add_to_chat(207, line)
        end
	end
end)

windower.register_event('login', function(name)
	player = windower.ffxi.get_player()
	playerZone = windower.ffxi.get_info().zone
	settings = config.load(defaults)
end)

windower.register_event('logout', function(name)
	myTarget = nil
	player = nil
	clearEnmityList()
end)

windower.register_event('target change', function(index)
	myTarget = windower.ffxi.get_mob_by_target('t')
	if debugInfo.startTime and debugInfo.selectTime then
		debugInfo.switchTime = os.clock()
		debugBox.selectTime = string.format("%.3f", tostring(debugInfo.selectTime - debugInfo.startTime))
		debugBox.switchTime = string.format("%.3f", tostring(debugInfo.switchTime - debugInfo.startTime))
		debugInfo.startTime = nil
		debugInfo.selectTime = nil
		debugInfo.switchTime = nil
	end
end)

windower.register_event('status change', function(new, old)
    if new == 1 then
		engaged = true
		myTarget = windower.ffxi.get_mob_by_target('t')
		lastSelectedID = myTarget and myTarget.id or nil
		addToHistory(myTarget)
	elseif new == 4 then
		state.cs = true
		engaged = false
	else 
		engaged = false
		myTarget = nil
		state.cs = false
	end
end)

windower.register_event('zone change', function(new_id, old_id)
	myTarget = nil
	clearEnmityList()
	playerZone = new_id
end)

windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)
	if id == 0x029 then -- Action Message
		actionMessageHandler(packets.parse('incoming', data))
	elseif id == 0x0DD then -- Party information message
		partyMessageHandler(packets.parse('incoming', data))
	elseif id == 0x067 then -- Pet information message
		petInfoMessageHandler(packets.parse('incoming', data))
	elseif id == 0x037 then -- Update Char message
		
	elseif id == 0x058 then -- Lock Target (Reply from server when a switch target or engage message is sent)
		if not injected then
			if lockTargetHandler(packets.parse('incoming', data)) then return true end
		end
	end
end)

windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
	if id == 0x01A and not injected then -- Action
		targetChangeHandler(packets.parse('outgoing', data))
	end
end)

windower.register_event('action', function(act)
	if actionCategories:contains(act.category) then
		local actorID = act.actor_id
		local targetID = nil
		local pc = nil
		local mob = nil
		for i,v in ipairs(act.targets) do
			targetID = v.id
			pc = nil
			mob = nil
			if isAlly(actorID) then
				pc = actorID
			elseif isNPC(actorID) then
				mob = actorID
			end
			if isAlly(targetID) then
				pc = targetID
			elseif isNPC(targetID) then
				mob = targetID
			end
			if pc and mob then
				local mobData = windower.ffxi.get_mob_by_id(mob)
				if pc == actorID and i == 1 and windower.ffxi.get_mob_by_id(actorID).name:lower() == ratName then
					ratTarget = mob
				end
				if not enmityList[mob] and mobData.valid_target and not untargetableEntities:contains(mobData.name:lower()) then
					if mobData.name:contains("'s ") or mobData.name:contains("Luopan") then
						if settings.petFilter == false then
							enmityList[mob] = {name = mobData.name, id = mobData.id}
							if not enmityListNames:contains(mobData.name) then enmityListNames:append(mobData.name) end
						end
					elseif not blacklist:contains(string.lower(mobData.name)) then
						enmityList[mob] = {name = mobData.name, id = mobData.id}
						debugInfo.enemyCount = enmityList:length()
						if not enmityListNames:contains(mobData.name) then enmityListNames:append(mobData.name) end
					end
				end
			end
		end
	end
end)

windower.register_event('mouse', function(type, x, y, delta, blocked)
	if blocked or not settings.enmityBar.show or enmityList:empty() then return end
	if type == 1 then -- Left button click
		return mouseClickHandler(x, y)
	end
	if type == 2 then -- Left button release
		return mouseReleaseHandler(x, y)
	end
end)

windower.register_event('prerender', function()
	if os.clock() - timestamp > 1 then
		destroyZombies()
		timestamp = os.clock()
	end
	if player then
		updateEnmityBars(settings.enmityBar.show)
		updateRatBar(true)
	else
		myTarget = nil
		updateEnmityBars(false)
		updateRatBar(false)
	end
	if state.debug and not state.cs then
		if not debugBox:visible() then debugBox:show() end
		debugBox.enemyCount = tostring(debugInfo.enemyCount)
		debugBox.lastName = debugInfo.lastName
		debugBox.lastID = debugInfo.lastID
	elseif debugBox:visible() then debugBox:hide()
	end
end)

function initEnmityBars()
	if not enmityBars:empty() then
		for i,v in ipairs(enmityBars) do
			bar.destroy(v)
		end
	end
	enmityBars = T{}
	local posY = settings.enmityBar.posY
	for i=1, settings.enmityBar.maxCount do
		enmityBars[i] = bar.new(settings.enmityBar)
		bar.setPos(enmityBars[i], settings.enmityBar.posX, posY)
		if settings.enmityBar.stack == 'down' then
			posY = posY + settings.enmityBar.stackPad
		else
			posY = posY - settings.enmityBar.stackPad
		end
	end
end

function updateEnmityBars(show)
	if enmityBars:empty() then return end
	local enBarNum = 1
	if state.setup then
		for i=1, (enmityBars and #enmityBars or 0) do
			bar.setTextColor(enmityBars[i], {red=255, green=255, blue=255})
			bar.show(enmityBars[i])
			bar.update(enmityBars[i], "Target Name", "100", "0.0", nil)
		end
	else
		if show and not state.cs then
			local sortedEnmity = getSortedEnmityList()
			local listStartPoint = (enmityListPage - 1) * settings.enmityBar.maxCount + 1
			if listStartPoint > sortedEnmity:length() then enmityListPage = enmityListPage -1 return end
			for i=listStartPoint, sortedEnmity:length() do
				if enBarNum > settings.enmityBar.maxCount then break end
				local v = sortedEnmity[i]
				local enBar = enmityBars[enBarNum]
				if v and enBar then
					bar.show(enBar)
					bar.update(enBar, v.name, v.hpp, v.dist, v.id)
					if myTarget and v.id == myTarget.id then 
						bar.setTextColor(enBar, {red=200, green=50, blue=50}) 
					else
						bar.setTextColor(enBar, {red=255, green=255, blue=255})
					end
					enBarNum = enBarNum + 1
				end
			end
		end
		for i = enBarNum, (enmityBars and #enmityBars or 0) do
			local enBar = enmityBars[i]
			if enBar then
				bar.hide(enBar)
			end
		end
	end
end

function getSortedEnmityList()
	local sorted = T{}
	local mob
	for i,v in pairs(enmityList) do
		mob = windower.ffxi.get_mob_by_id(v.id)
		if mob then
			v.hpp = mob.hpp
			v.dist = mob.distance:sqrt()
			sorted:append(v)
		end
	end
	local name_sort = function(a, b)
		return a.name:lower() < b.name:lower()
	end
	sorted:sort(name_sort)
	return sorted
end

function initRatBar()
	if ratBar then
		bar.destroy(ratBar)
	end
	ratBar = bar.new(settings.ratBar)
	bar.setPos(ratBar, settings.ratBar.posX, settings.ratBar.posY)
end

function updateRatBar(show)
	if not ratBar then return end
	if state.setup then
		bar.setRat(ratBar, "Raid Assist Target")
		bar.show(ratBar)
		bar.update(ratBar, "Target Name", "100", "0.0", nil)
	else
		if show and ratName and ratName:length() > 0 and not state.cs then
			local ratMob
			bar.setRat(ratBar, ratName:ucfirst())
			bar.show(ratBar)
			if ratTarget then 
				ratMob = windower.ffxi.get_mob_by_id(ratTarget)
				bar.update(ratBar, ratMob.name, tostring(ratMob.hpp), ratMob.distance:sqrt(), ratTarget)
			else
				bar.update(ratBar, "No Target", "0", "0.0", nil)
			end
		else
			bar.setRat(ratBar, nil)
			bar.hide(ratBar)
		end
	end
end

function listPageNext()
	enmityListPage = enmityListPage + 1
end

function listPagePrev()
	enmityListPage = enmityListPage - 1
	if enmityListPage < 1 then enmityListPage = 1 end
end

function determineNextBestTarget(...)
	if playerCharmed() then return end
	local args	= T{...}:map(string.lower)
	local mob
	local mobsInRange = T{}
	local mobsFullHP = T{}
	local mobsMissingHp = T{}
	local selectedMobID = nil
	local selectedMobIndex = nil
	local myTargetName
	local myTargetNameSplit = T{}
	local selectedMobName
	local selectedMobNameSplit = T{}
	local mobsNameMatch = T{}
	local mobsNameMatchFHP = T{}
	local mobsNameMatchMHP = T{}
	local mobsNamePartial = T{}
	local mobsNamePartialFHP = T{}
	local mobsNamePartialMHP = T{}
	for i,v in pairs(enmityList) do
		mob = windower.ffxi.get_mob_by_id(v.id)
		if mob and mob.hpp > 0 then
			if mob.valid_target and mob.distance:sqrt() <= settings.maxDist and mob.id ~= myTarget.id then
				if args[1] == "next" and previousSelectedIDs:contains(mob.id) then -- No continue command in LUA? :(
				elseif args[1] == "nextdiff" and previousSelectedNames:contains(mob.name) then
				else	
					mobsInRange:append(mob)
					if mob.hpp == 100 then
						mobsFullHP:append(mob)
					else
						mobsMissingHp:append(mob)
					end
					if settings.preferSimilar then
						myTargetName = myTarget.name
						myTargetNameSplit = T(string.split(myTargetName, " "))
						selectedMobName = mob.name
						selectedMobNameSplit = T(string.split(selectedMobName, " "))
						if myTargetName == selectedMobName then	
							mobsNameMatch:append(mob)
							if mob.hpp == 100 then 
								mobsNameMatchFHP:append(mob)
							else 
								mobsNameMatchMHP:append(mob) 
							end
						elseif myTargetNameSplit:length() > 1 and selectedMobNameSplit:length() > 1 then
							if myTargetNameSplit[1] == selectedMobNameSplit[1] then 
								mobsNamePartial:append(mob) 
								if mob.hpp == 100 then
									mobsNamePartialFHP:append(mob)
								else
									mobsNamePartialMHP:append(mob)
								end
							end
						end
					end
				end
			end
		elseif mob and mob.hpp == 0 then
			enmityList[mob.id] = nil
			if mob.id == ratTarget then ratTarget = nil end
			removeFromHistory(mob)
		end
	end
	if mobsInRange:length() > 0 then
		local distance_sort = function(low, high)
			return low.distance < high.distance
		end
		local hp_sort_high = function(low, high)
			return high.hpp < low.hpp
		end
		local hp_sort_low = function(low, high)
			return low.hpp < high.hpp
		end
		if not mobsNameMatch:empty() or not mobsNamePartial:empty() then
			mobsNameMatch = mobsNameMatch:sort(distance_sort)
			mobsNamePartial = mobsNamePartial:sort(distance_sort)
			mobsNameMatchFHP = mobsNameMatchFHP:sort(distance_sort)
			mobsNamePartialFHP = mobsNamePartialFHP:sort(distance_sort)
			if settings.mobHPFilter == "highest" then
				mobsNameMatchMHP = mobsNameMatchMHP:sort(hp_sort_high)
				mobsNamePartialMHP = mobsNamePartialMHP:sort(hp_sort_high)
			elseif settings.mobHPFilter == "lowest" then
				mobsNameMatchMHP = mobsNameMatchMHP:sort(hp_sort_low)
				mobsNamePartialMHP = mobsNamePartialMHP:sort(hp_sort_low)
			end
		else
			mobsInRange = mobsInRange:sort(distance_sort)
			mobsFullHP = mobsFullHP:sort(distance_sort)
			if settings.mobHPFilter == "highest" then
				mobsMissingHp = mobsMissingHp:sort(hp_sort_high)
			elseif settings.mobHPFilter == "lowest" then
				mobsMissingHp = mobsMissingHp:sort(hp_sort_low)
			end
		end
		
		if not mobsNameMatch:empty() then
			if settings.mobHPFilter == "highest" and not mobsNameMatchFHP:empty() then
				selectedMobID = mobsNameMatchFHP:first().id
				selectedMobIndex = mobsNameMatchFHP:first().index
			end
			if settings.mobHPFilter == "lowest" or mobsNameMatchFHP:empty() then
				if not mobsNameMatchMHP:empty() then
					selectedMobID = mobsNameMatchMHP:first().id
					selectedMobIndex = mobsNameMatchMHP:first().index
				else
					selectedMobID = mobsNameMatch:first().id
					selectedMobIndex = mobsNameMatch:first().index
				end
			end
			if settings.mobHPFilter == "none" then
				selectedMobID = mobsNameMatch:first().id
				selectedMobIndex = mobsNameMatch:first().index
			end
		elseif not mobsNamePartial:empty() then
			if settings.mobHPFilter == "highest" and not mobsNamePartialFHP:empty() then
				selectedMobID = mobsNamePartialFHP:first().id
				selectedMobIndex = mobsNamePartialFHP:first().index
			end
			if settings.mobHPFilter == "lowest" or mobsNamePartialFHP:empty() then
				if not mobsNamePartialMHP:empty() then
					selectedMobID = mobsNamePartialMHP:first().id
					selectedMobIndex = mobsNamePartialMHP:first().index
				else
					selectedMobID = mobsNamePartial:first().id
					selectedMobIndex = mobsNamePartial:first().index
				end
			end
			if settings.mobHPFilter == "none" then
				selectedMobID = mobsNamePartial:first().id
				selectedMobIndex = mobsNamePartial:first().index
			end
		else
			if settings.mobHPFilter == "highest" and not mobsFullHP:empty() then
				selectedMobID = mobsFullHP:first().id
				selectedMobIndex = mobsFullHP:first().index
			end
			if settings.mobHPFilter == "lowest" or mobsFullHP:empty() then 
				if not mobsMissingHp:empty() then
					selectedMobID = mobsMissingHp:first().id
					selectedMobIndex = mobsMissingHp:first().index
				else
					selectedMobID = mobsInRange:first().id
					selectedMobIndex = mobsInRange:first().index
				end
			end
			if settings.mobHPFilter == "none" then
				selectedMobID = mobsInRange:first().id
				selectedMobIndex = mobsInRange:first().index
			end
		end
		
		if selectedMobID and selectedMobIndex then targetSpecificMob(selectedMobID, selectedMobIndex) end
		debugMobSelected(windower.ffxi.get_mob_by_id(selectedMobID))
	elseif args[1] == "next" and not previousSelectedIDs:empty() then
		mob = windower.ffxi.get_mob_by_id(previousSelectedIDs:remove(1))
		targetSpecificMob(mob.id, mob.index)
		debugMobSelected(mob)
	elseif args[1] == "nextdiff" then
		if previousSelectedNames:length() > 1 then
			previousSelectedNames:remove(1)
			determineNextBestTarget("nextdiff")
		end
	else
		disengageMe()
	end
end

function targetSpecificMob(mobID, mobIndex)
	if not mobID or not mobIndex then return end
	-- Inject packets for switching target both outgoing and incoming
	if engaged then 
		packets.inject(packets.new('outgoing', 0x01A, {
			['Target'] = mobID,
			['Target Index'] = mobIndex,
			['Category'] = 15,
		}))
	end
	packets.inject(packets.new('incoming', 0x058, {
		['Player'] = player.id,
		['Target'] = mobID,
		['Player Index'] = player.index,
	}))
	lastSelectedID = mobID
	addToHistory(windower.ffxi.get_mob_by_id(mobID))
end

function targetPrevious()
	if playerCharmed() then return end
	if previousSelectedIDs:length() <= 1 then return end
	previousSelectedIDs:delete(previousSelectedIDs:last())
	local mob = windower.ffxi.get_mob_by_id(previousSelectedIDs:delete(previousSelectedIDs:last()))
	targetSpecificMob(mob.id, mob.index)
	debugMobSelected(mob)
end

function ratAssist()
	if playerCharmed() then return end
	if ratName and ratTarget then
		local mob = windower.ffxi.get_mob_by_id(ratTarget)
		if mob and mob.id and mob.index then targetSpecificMob(mob.id, mob.index) end
	else
		if not ratName then addonMessage("No raid assist target set") end
		if not ratTarget then addonMessage("Assist target not valid") end
	end
end

function disengageMe()
	local player = windower.ffxi.get_player()
	if player.status == 1 then
		packets.inject(packets.new('outgoing', 0x01A, {
			['Target'] = player.id,
			['Target Index'] = player.index,
			['Category'] = 4,
		}))
	end
	lastSelectedID = nil
end

function destroyZombies()
	for i,v in pairs(enmityList) do
		mob = windower.ffxi.get_mob_by_id(v.id)
		if mob and mob.hpp == 0 then
			enmityList[mob.id] = nil
			if mob.id == ratTarget then ratTarget = nil end
			removeFromHistory(mob)
		end
	end
end

function clearEnmityList()
	enmityList = T{}
	enmityListNames = T{}
	lastSelectedID = nil
	previousSelectedIDs = T{}
	previousSelectedNames = T{}
	debugInfo.enemyCount = enmityList:length()
end

function addToHistory(mob)
	if not mob or not mob.id or not mob.name then return end
	if previousSelectedIDs:contains(mob.id) then previousSelectedIDs:delete(mob.id) end
	previousSelectedIDs:append(mob.id)
	if previousSelectedNames:contains(mob.name) then previousSelectedNames:delete(mob.name) end
	previousSelectedNames:append(mob.name)
end

function removeFromHistory(mob)
	if not mob or not mob.id or not mob.name then return end
	previousSelectedIDs:delete(mob.id)
	local name_exists = function(val)
		if val.name == mob.name then return true end
	end
	if not enmityList:find(name_exists) then 
		enmityListNames:delete(mob.name)
		previousSelectedNames:delete(mob.name)
	end
end

function debugMobSelected(mob)
	debugInfo.selectTime = os.clock()
	debugInfo.lastName = mob.name
	debugInfo.lastID = mob.id
end

function addToBlacklist(argTable)
	local mobNameLower = ""
	if argTable[1] == "t" then
		local mob = windower.ffxi.get_mob_by_target('t')
		mobNameLower = string.lower(mob.name)
		if mob and mob.is_npc and not blacklist:contains(mobNameLower) then
			blacklist:add(mobNameLower)
			addonMessage("blacklist added: " .. mob.name)
		end
	else
		for _,v in pairs(argTable) do
			mobNameLower = mobNameLower .. string.lower(v) .. " "
		end
		mobNameLower = mobNameLower:trim()
		blacklist:add(mobNameLower)
		addonMessage("blacklist added: " .. mobNameLower)
	end
	if mobNameLower:length() > 0 then
		for i,v in pairs(enmityList) do
			if mobNameLower == string.lower(v.name) then
				removeFromHistory(v)
				enmityList[i] = nil
			end
		end
	end
end

function removeFromBlacklist(argTable)
	if argTable[1] == "t" then
		local mob = windower.ffxi.get_mob_by_target('t')
		local mobNameLower = string.lower(mob.name)
		if mob and mob.is_npc and blacklist:contains(mobNameLower) then
			blacklist:remove(mobNameLower)
			addonMessage("blacklist removed: " .. mob.name)
		end
	else
		local mobNameLower = ""
		for _,v in pairs(argTable) do
			mobNameLower = mobNameLower .. string.lower(v) .. " "
		end
		mobNameLower = mobNameLower:trim()
		if blacklist:contains(mobNameLower) then
			blacklist:remove(mobNameLower)
			addonMessage("blacklist removed: " .. mobNameLower)
		end
	end
end

function isAlly(id)
	if id == player.id then return true end
	if isNPC(id) then return false end
	if partyPets[id] and partyMembers[partyPets[id].owner] then return true end
	if partyMembers[id] == nil then return false end
	return partyMembers[id]
end

function isNPC(id)
	local entity = windower.ffxi.get_mob_by_id(id)
	if not entity then return nil end
	return entity.is_npc and not entity.charmed
end

function findPartStrMatch(t, str)
	for i, v in pairs(t) do
		if i:startswith(str) then return i end
	end
	return false
end

function playerInZone(zone)
	if playerZone == zone then return true end
	return false
end

function playerCharmed()
	local player = windower.ffxi.get_player()
	for i,v in pairs(player.buffs) do
		if res.buffs[v] and res.buffs[v].english and res.buffs[v].english:lower() == 'charm' then return true end
	end
	return false
end

function recordPartyMembers(p, pNum)
	if p and playerInZone(p.zone) then partyMemebersInZone = partyMemebersInZone + 1 end
	if p and p.mob and not partyMembers[p.mob.id] then
		partyMembers[p.mob.id] = {name = p.name, party = pNum}
		partyMemberNames:add(p.name:lower())
	end
end

function scanForPartyMembers()
	local party = windower.ffxi.get_party()
	if not party then return end
	partyMembers = T{}
	partyMemberNames = S{}
	partyMemebersInZone = 0
	local member
	for i=0, (party.party1_count or 0) -1 do
		member = party['p'..tostring(i)]
		recordPartyMembers(member, 1)
	end
	for i=0, (party.party2_count or 0) -1 do
		member = party['a1'..tostring(i)]
		recordPartyMembers(member, 2)
	end
	for i=0, (party.party3_count or 0) -1 do
		member = party['a2'..tostring(i)]
		recordPartyMembers(member, 3)
	end
	if partyMembers:length() < partyMemebersInZone then -- Not everyone was in range to get mob data from get_party() 
		coroutine.schedule(scanForPartyMembers, 5)
	end
end

function addonMessage(msg)
	if not msg or type(msg) ~= "string" then return end
	windower.add_to_chat(207, _addon.name .." ".. msg)
end

function actionMessageHandler(amPacket)
	-- If enemy defeated or falls to the ground message
	if amPacket.Message == 6 or amPacket.Message == 20 then
		local mobData = windower.ffxi.get_mob_by_id(amPacket.Target)
		if enmityList[mobData.id] then enmityList[mobData.id] = nil end
		debugInfo.enemyCount = enmityList:length()
		if mobData.id == ratTarget then ratTarget = nil end
		removeFromHistory(mobData)
		if engaged and myTarget and myTarget.id == mobData.id then
			if not enmityList:empty() and targetingOn and not state.cs then
				-- destroyZombies()
				debugInfo.startTime = os.clock()
				determineNextBestTarget()
			else
				disengageMe()
			end
		end
	end
end

function lockTargetHandler(ltPacket) -- Hopefully stop addon from locking on to things multiple times
	local mobInfo = windower.ffxi.get_mob_by_id(ltPacket.Target)
	if lockTargetResponse and mobInfo.id == lockTargetResponse then return true end
	if lastSelectedID and myTarget and myTarget.id ~= lastSelectedID and lastSelectedID == mobInfo.id then return true end
	if mobInfo.hpp == 0 or mobInfo.status == 2 then	return true	end
	lockTargetResponse = mobInfo.id
	return false
end

function targetChangeHandler(tcPacket) -- Handle the player manually targeting
	if  tcPacket.Category == 15 then 
		if enmityList:contains(tcPacket.Target) then addToHistory(windower.ffxi.get_mob_by_id(tcPacket.Target)) end
		if lastSelectedID and tcPacket.Target == lastSelectedID then
			lastSelectedID = nil
		end
	end
end

function partyMessageHandler(pmPacket)
	scanForPartyMembers()
end

function petInfoMessageHandler(petPacket)
	if petPacket['Owner Index'] > 0 then
		local owner = windower.ffxi.get_mob_by_index(petPacket['Owner Index'])
		if owner then
			if isAlly(owner.id) and not partyPets[petPacket['Pet ID']] then
				partyPets[petPacket['Pet ID']] = {owner = owner.id}
			elseif not isAlly(owner.id) and partyPets[petPacket['Pet ID']] then
				partyPets[petPacket['Pet ID']] = nil
			end
		end
	end
end

function mouseClickHandler(x, y)
	for _, v in ipairs(enmityBars) do
		if bar.hover(v, x, y) then
			local mob = windower.ffxi.get_mob_by_id(bar.getID(v))
			if mob and mob.id and mob.index then
				targetSpecificMob(mob.id, mob.index)
				return true
			end
		end
	end
	if bar.hover(ratBar, x, y) then
		local mob = windower.ffxi.get_mob_by_id(bar.getID(ratBar))
		if mob and mob.id and mob.index then 
			targetSpecificMob(mob.id, mob.index)
			return true
		end
	end
	return false
end

function mouseReleaseHandler(x, y)
	for _, v in ipairs(enmityBars) do
		if bar.hover(v, x, y) then return true end
	end
	if bar.hover(ratBar, x, y) then return true end
	return false
end

scanForPartyMembers()
initEnmityBars()
initRatBar()
if player and player.status == 1 then engaged = true else engaged = false end