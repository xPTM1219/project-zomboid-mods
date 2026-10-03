--[[
StepLadder server-side code: entity build callbacks and the MP toggle command.

[1] Climb behavior comes from the sprite's tile properties (stairsBW/stairsBN
    for steps, ladderN/ladderE for ladder), not from any script. The sprite
    the IsoThumpable carries is what matters; see newtiledefinitions.tiles.txt
    entries for carpentry_02_84..87 and fixtures_stairs_01.
[1b] Sprites must not be claimed by any other entity script: SpriteConfigManager
    aborts world loading on duplicate sprite names ("carpentry_02_96 is
    duplicate. entity script: Wood_Stairs"). The carpentry_02_88..98 stairs
    family is claimed by vanilla entities Wood_Stairs/Log Stairs/Welding
    Stairs, so steps mode uses fixtures_stairs_01_0/_8 instead.
[2] In multiplayer the client sends "toggle" and this server handler applies
    the sprite swap authoritatively (vanilla camping_tent.lua flow). In single
    player StepLadder_Toggle calls StepLadderCode.doToggle directly, since the
    OnClientCommand event does not fire there.
[3] A north-facing ladder leans against the wall of the square to the north
    (y-1); a west-facing one leans on the square to the west (x-1). Wall
    checks must inspect that neighbor square, not the object's own square.
[4] Vanilla carpentry stairs build a landing floor at z+1 over the top stair
    square (BuildRecipeCode.stairs.OnCreate). We keep the same landing logic
    in OnCreate so the step ladder is usable at the top level.
]]--

StepLadderCode = {}

local OBJECT_NAME = "StepLadder"

-- Stairs-type sprites by orientation (mode "steps"). Unclaimed by entity
-- scripts; carpentry_02_88..98 are reserved by vanilla stairs entities.
local SPRITE_STEPS_NORTH = "fixtures_stairs_01_8"   -- stairsBN
local SPRITE_STEPS_OTHER = "fixtures_stairs_01_0"   -- stairsBW
-- Wall-ladder sprites by orientation (mode "ladder").
local SPRITE_LADDER_NORTH = "carpentry_02_85" -- ladderN
local SPRITE_LADDER_OTHER = "carpentry_02_86" -- ladderE

local FLOOR_TILE = "carpentry_02_57"

function StepLadderCode.getSpriteFor(mode, north)
	if mode == "ladder" then
		return north and SPRITE_LADDER_NORTH or SPRITE_LADDER_OTHER
	end
	return north and SPRITE_STEPS_NORTH or SPRITE_STEPS_OTHER
end

function StepLadderCode.OnIsValid(params)
	local square = params.square
	if square:getZ() >= getMaximumWorldLevel() then
		return false
	end

	if square:HasStairs() then
		return false
	end

	if square:isSolid() or square:isSolidTrans() then
		return false
	end

	-- The landing floor needs room above; block placing under existing floors.
	local above = getCell():getGridSquare(square:getX(), square:getY(), square:getZ() + 1)
	if above and above:getFloor() then
		return false
	end

	-- One tile = bottom stair, so water placement is allowed like vanilla.
	if square:getZ() == 0 then
		params.canBuildOverWater = true
	end

	return true
end

function StepLadderCode.OnCreate(params)
	-- See note [4] in this file docstring.
	local thumpable = params.thumpable
	local square = thumpable:getSquare()

	local d = thumpable:getModData()
	d.SL = { mode = "steps", north = thumpable:getNorth() }
	thumpable:setObjectName(OBJECT_NAME)

	local x = square:getX()
	local y = square:getY()
	local z = thumpable:getZ()

	-- Landing floor above the ladder square, so climbing reaches z+1.
	local above = nil
	if getWorld():isValidSquare(x, y, z + 1) then
		above = getCell():getGridSquare(x, y, z + 1)
		if above == nil then
			above = IsoGridSquare.new(getCell(), nil, x, y, z + 1)
			getCell():ConnectNewSquare(above, false)
		end
		if not above:getProperties():has(IsoFlagType.solidfloor) then
			above:addFloor(FLOOR_TILE)
		end
	end
	if above then
		above:RecalcAllWithNeighbours(true)
	end

	square:RecalcAllWithNeighbours(true)
	return nil
end

-- Apply the mode swap in place. Runs on the server in MP, and directly in SP.
function StepLadderCode.doToggle(ladder)
	local d = ladder:getModData()
	d.SL = d.SL or { mode = "steps", north = ladder:getNorth() }
	local north = ladder:getNorth()

	-- Untested risk: whether IsoObjectType is re-derived from the new sprite
	-- on setSpriteFromName. If ladder mode is not climbable in-game, replace
	-- this with remove-and-re-add (transmitRemoveItemFromSquare +
	-- RemoveTileObject, then new IsoThumpable + transmitCompleteItemToClients),
	-- preserving d.SL. See ISOpenCloseLid for the re-add pattern.
	if d.SL.mode == "steps" then
		ladder:setSpriteFromName(StepLadderCode.getSpriteFor("ladder", north))
		d.SL.mode = "ladder"
	else
		ladder:setSpriteFromName(StepLadderCode.getSpriteFor("steps", north))
		d.SL.mode = "steps"
	end
	ladder:transmitUpdatedSpriteToClients()
end

local function findLadder(x, y, z)
	local square = getCell():getGridSquare(x, y, z)
	if not square then
		return nil
	end
	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do
		local obj = objects:get(i)
		if instanceof(obj, "IsoThumpable") and obj:getName() == OBJECT_NAME then
			return obj
		end
	end
	return nil
end

-- See note [2] in this file docstring.
local function OnClientCommand(module, command, player, args)
	if module ~= "StepLadder" or command ~= "toggle" then
		return
	end
	if type(args) ~= "table" or type(args.x) ~= "number" or type(args.y) ~= "number" or type(args.z) ~= "number" then
		return
	end
	local ladder = findLadder(args.x, args.y, args.z)
	if not ladder then
		return
	end
	local d = ladder:getModData()
	if not d or not d.SL then
		return
	end
	StepLadderCode.doToggle(ladder)
end

Events.OnClientCommand.Add(OnClientCommand)