require "TimedActions/ISBaseTimedAction"

StepLadder_Toggle = ISBaseTimedAction:derive("StepLadder_Toggle");

-- Sprite families per mode. See note [1] in the docstring of StepLadderCode
-- in StepLadder_Server.lua: the sprite properties (stairsBW/stairsBN,
-- ladderN/ladderE) drive climb behavior, not the object script. Note [1b]:
-- steps sprites must be unclaimed by any other entity script.
StepLadder_Toggle.SPRITES = {
	steps = { north = "fixtures_stairs_01_8", other = "fixtures_stairs_01_0" },
	ladder = { north = "carpentry_02_85", other = "carpentry_02_86" },
}

function StepLadder_Toggle:isValid()
	return self.ladder ~= nil and self.ladder:getSquare() ~= nil
end

function StepLadder_Toggle:waitToStart()
	self.character:faceThisObject(self.ladder)
	return self.character:shouldBeTurning()
end

function StepLadder_Toggle:update()
	self.character:faceThisObject(self.ladder)
	self.character:setMetabolicTarget(Metabolics.LightWork)
end

function StepLadder_Toggle:start()
	self:setActionAnim("Loot")
	self.character:faceThisObject(self.ladder)
end

function StepLadder_Toggle:stop()
	ISBaseTimedAction.stop(self)
end

function StepLadder_Toggle:perform()
	ISBaseTimedAction.perform(self)
end

function StepLadder_Toggle:complete()
	if isClient() then
		-- See note [2] in StepLadder_Server.lua docstring: in MP the server
		-- applies the toggle authoritatively.
		local sq = self.ladder:getSquare()
		sendClientCommand(self.character, "StepLadder", "toggle",
			{ x = sq:getX(), y = sq:getY(), z = sq:getZ() })
	else
		StepLadderCode.doToggle(self.ladder)
	end
	return true
end

function StepLadder_Toggle:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 30
end

function StepLadder_Toggle:new(character, ladder)
	local o = ISBaseTimedAction.new(self, character)
	o.character = character
	o.ladder = ladder
	o.maxTime = 30
	if character:isTimedActionInstant() then
		o.maxTime = 1
	end
	return o
end