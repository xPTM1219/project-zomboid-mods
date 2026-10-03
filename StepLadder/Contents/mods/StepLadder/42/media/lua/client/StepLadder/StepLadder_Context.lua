StepLadder_Context = {}

local OBJECT_NAME = "StepLadder"

local function isStepLadder(obj)
	if not instanceof(obj, "IsoThumpable") then
		return false
	end
	if obj:getName() == OBJECT_NAME then
		return true
	end
	local d = obj:getModData()
	return d ~= nil and d.SL ~= nil
end

-- The ladder leans against the wall of the neighboring square: north mode
-- leans on the square to the north (y-1), otherwise on the square to the
-- west (x-1). See note [3] in StepLadder_Server.lua.
local function wallBehind(ladder)
	local north = ladder:getNorth()
	local sq = ladder:getSquare()
	local target = getCell():getGridSquare(
		north and sq:getX() or sq:getX() - 1,
		north and sq:getY() - 1 or sq:getY(),
		sq:getZ())
	if not target then
		return false
	end
	local props = target:getProperties()
	if not props then
		return false
	end
	if north then
		return props:has(IsoFlagType.WallN) or props:has(IsoFlagType.WallNW)
	end
	return props:has(IsoFlagType.WallW) or props:has(IsoFlagType.WallNW)
end

local function onToggle(ladder, playerObj)
	if luautils.walkAdj(playerObj, ladder:getSquare(), false) then
		ISTimedActionQueue.add(StepLadder_Toggle:new(playerObj, ladder))
	end
end

function StepLadder_Context.doMenu(player, context, worldobjects, test)
	if test and ISWorldObjectContextMenu.Test then
		return true
	end

	local playerObj = getSpecificPlayer(player)
	if not playerObj then
		return
	end

	local ladder = nil
	for _, obj in ipairs(worldobjects) do
		if isStepLadder(obj) then
			ladder = obj
			break
		end
	end
	if not ladder then
		return
	end

	if not AdjacentFreeTileFinder.isTileOrAdjacent(playerObj:getCurrentSquare(), ladder:getSquare()) then
		return
	end

	local d = ladder:getModData()
	local mode = (d and d.SL and d.SL.mode) or "steps"

	local text, canToggle
	if mode == "steps" then
		text = getText("ContextMenu_UnfoldLadder")
		canToggle = wallBehind(ladder)
	else
		text = getText("ContextMenu_FoldLadder")
		canToggle = true
	end

	local option = context:addOption(text, ladder, onToggle, playerObj)
	if not canToggle then
		option.notAvailable = true
		local tooltip = ISWorldObjectContextMenu.addToolTip()
		tooltip:setName(text)
		tooltip.description = getText("Tooltip_StepLadder_NeedsWall")
		option.toolTip = tooltip
	end
end

Events.OnFillWorldObjectContextMenu.Add(StepLadder_Context.doMenu)