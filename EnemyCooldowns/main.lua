local ADDON_NAME,engine = ...

local GROUPS_OFFSET = 22
local POSITION_X,POSITION_Y = 400,-180
local CHARS_LIMIT = 8
local COMBATLOG_OBJECT_REACTION_NEUTRAL = COMBATLOG_OBJECT_REACTION_NEUTRAL
local COMBATLOG_OBJECT_REACTION_HOSTILE	= COMBATLOG_OBJECT_REACTION_HOSTILE
local COMBATLOG_OBJECT_REACTION_MASK = COMBATLOG_OBJECT_REACTION_MASK
local CLASS2HEXCOLOR = {}
local SPELLS,RESETTERS = engine.SPELLS,engine.RESETTERS
local table = engine.table
local bit = bit
local next = next
local GetTime = GetTime
local strlenutf8 = strlenutf8


local eventFrame = CreateFrame("frame")
local trackers,unusedTrackers = {},{}
local trackersOrder,targetGUID = {}
local cooldownInfo,GUID2name = {},{}

do
	local function RGBPercToHex(r, g, b)
		r = r <= 1 and r >= 0 and r or 0
		g = g <= 1 and g >= 0 and g or 0
		b = b <= 1 and b >= 0 and b or 0
		return ("|cff%02x%02x%02x"):format(r*255, g*255, b*255)
	end

	CLASS2HEXCOLOR["none"] = RGBPercToHex(0.4,0.4,0.4)
	for class,c in pairs(RAID_CLASS_COLORS) do
		CLASS2HEXCOLOR[class] = RGBPercToHex(math.min(c.r*1.25,1),math.min(c.g*1.25,1),math.min(c.b*1.25,1))
	end
end



function engine:Cleanup(GUID)
	local cooldownInfo_GUID = cooldownInfo[GUID]
	if not cooldownInfo_GUID then return end

	local curTime = GetTime()
	for spellID,timeStamp in next,cooldownInfo_GUID do
		if curTime >= timeStamp then
			cooldownInfo_GUID[spellID] = nil
		end
	end

	if not next(cooldownInfo_GUID) then
		cooldownInfo[GUID] = table.del(cooldownInfo_GUID)
	end
end

function engine:GetCooldownInfo(GUID)
	self:Cleanup(GUID)
	return cooldownInfo[GUID]
end

function engine:UpdatePositions()
	if #trackersOrder == 0 then return end

	trackers[trackersOrder[1]]:SetPoint("LEFT",UIParent,POSITION_X,POSITION_Y)
	for i = 2,#trackersOrder do
		trackers[trackersOrder[i]]:SetPoint("LEFT",trackers[trackersOrder[i-1]],"RIGHT",GROUPS_OFFSET,0)
	end
end

function engine:SpawnTracker(GUID)
	local tracker = table.remove(unusedTrackers) or self:CreateGroup()
	tracker:Initialize(GUID,GUID2name[GUID])
	trackers[GUID] = tracker

	if GUID == targetGUID then
		table.insert(trackersOrder,1,GUID)
	else
		table.insert(trackersOrder,GUID)
	end

	self:UpdatePositions()

	return tracker
end

function engine:UpdateTracker(GUID)
	local cooldownInfo_GUID = self:GetCooldownInfo(GUID)
	if cooldownInfo_GUID then
		local tracker = trackers[GUID] or self:SpawnTracker(GUID)
		tracker:Update(cooldownInfo_GUID)
	else
		self:ReleaseTracker(GUID)
	end
end

function engine:ReleaseTracker(GUID)
	if table.removeByValue(trackersOrder,GUID) then
		local tracker = trackers[GUID]
		tracker:Release()
		trackers[GUID] = nil
		table.insert(unusedTrackers,tracker)

		self:UpdatePositions()
	end
end

function engine:ReleaseAllTrackers()
	local GUID,tracker
	for i = 1,#trackersOrder do
		GUID = trackersOrder[i]
		tracker = trackers[GUID]
		tracker:Release()
		trackers[GUID],trackersOrder[i] = nil
		table.insert(unusedTrackers,tracker)
	end
end

function engine:AddCooldown(GUID,spellID,timeEnd)
	cooldownInfo[GUID] = cooldownInfo[GUID] or table.new()
	cooldownInfo[GUID][spellID] = timeEnd
end

function engine:RemoveCooldown(GUID,spellIDList)
	local cooldownInfo_GUID = cooldownInfo[GUID]
	if not cooldownInfo_GUID then return end

	if spellIDList then
		local spellID
		for i = 1,#spellIDList do
			spellID = spellIDList[i]
			cooldownInfo_GUID[spellID] = nil
		end

		if not next(cooldownInfo_GUID) then
			cooldownInfo[GUID] = table.del(cooldownInfo_GUID)
		end
	else
		cooldownInfo[GUID] = table.del(cooldownInfo_GUID)
	end
end

function engine:ResetCooldownInfo()
	for k,v in next,cooldownInfo do
		cooldownInfo[k] = table.del(v)
	end
	table.wipe(GUID2name)
end

function engine:COMBAT_LOG_EVENT_UNFILTERED(_,subEvent,...)
	if subEvent == "SPELL_CAST_SUCCESS" then
		local srcGUID,srcName,srcFlags,_,_,_,spellID = ...

		local reaction = bit.band(srcFlags,COMBATLOG_OBJECT_REACTION_MASK)
		if reaction == COMBATLOG_OBJECT_REACTION_HOSTILE or reaction == COMBATLOG_OBJECT_REACTION_NEUTRAL then
			local isUpdateRequired

			local resetList = RESETTERS[spellID]
			if resetList then
				self:RemoveCooldown(srcGUID,resetList)
				isUpdateRequired = true
			end

			local cooldownDuration = SPELLS[spellID]
			if cooldownDuration then
				self:AddCooldown(srcGUID,spellID,GetTime()+cooldownDuration)
				isUpdateRequired = true
			end

			if isUpdateRequired then
				if not GUID2name[srcGUID] then
					local _,class = GetPlayerInfoByGUID(srcGUID)
					srcName = (srcName or ""):gsub("-.*$","")
					local nonAscii = strlenutf8(srcName) ~= #srcName
					GUID2name[srcGUID] = CLASS2HEXCOLOR[class or "none"]..srcName:sub(1,nonAscii and CHARS_LIMIT*2 or CHARS_LIMIT)
				end

				self:UpdateTracker(srcGUID)
			end
		end
	end
end

function engine:PLAYER_TARGET_CHANGED()
	targetGUID = UnitGUID("target")
	if targetGUID and trackers[targetGUID] then
		for i = 1,#trackersOrder do
			if trackersOrder[i] == targetGUID then
				table.remove(trackersOrder,i)
				table.insert(trackersOrder,1,targetGUID)
				break
			end
		end

		self:UpdatePositions()
	end
end

function engine:PLAYER_ENTERING_WORLD()
	self:ReleaseAllTrackers()
	self:ResetCooldownInfo()
end


eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent",function(_,event,...)
	engine[event](engine,...)
end)

CombatLogSetRetentionTime(-1)