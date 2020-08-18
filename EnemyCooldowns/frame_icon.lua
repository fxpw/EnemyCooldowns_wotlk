local engine = select(2,...)

local setmetatable = setmetatable
local CreateFrame = CreateFrame
local GetTime = GetTime
local GetSpellInfo = GetSpellInfo
local math_floor = math.floor

local prototype = setmetatable({},getmetatable(UIParent))
local MT = {__index = prototype}

local spellID2texture = setmetatable({
	[71607] = "Interface\\Icons\\inv_jewelcrafting_gem_28", -- bauble of true blood
    [42292] = "Interface\\Icons\\Spell_Shadow_Charm", -- Medalion
},{
	__index = function(t,k)
		local _,_,v = GetSpellInfo(k)
		t[k] = v
		return v
	end,
})

local function math_round(x)
	return math_floor(x+0.51)
end

local function formatTime(v)
	if v > 0 then
		if v <= 3 then
		    return ("%.01f"):format(v)
		elseif v <= 60 then
			return math_round(v)
		elseif v <= 3600 then
			return math_round(v/60).."m"
		else
			return math_round(v/3600).."h"
		end
	end
end

local function frame_update_cb(self,elapsed)
	local remain = self.remain - elapsed
	self.remain = remain
	
	if remain > 0 then
		self.text:SetText(formatTime(remain))
	else
		self.text:SetText(nil)
		if remain < -0.1 then
			local tracker = self:GetParent()
			tracker:Update(engine:GetCooldownInfo(tracker.GUID))
		end
	end
end

function prototype:SetCooldown(timeEnd,duration)
	self.remain = timeEnd-GetTime()
	self:Show()
end

function prototype:SetSpell(spellID)
	self.texture:SetTexture(spellID2texture[spellID])
end

function engine:CreateIcon(parent)
	local frame = setmetatable(CreateFrame("frame",nil,parent),MT)
	frame:SetScript("OnUpdate",frame_update_cb)
	frame:SetFrameLevel(parent:GetFrameLevel())
	frame:Hide()

	local text = frame:CreateFontString(nil,"ARTWORK","NumberFontNormal")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT",frame,"RIGHT")

	local texture = frame:CreateTexture(nil,"BORDER")
	texture:SetAllPoints()


	frame.text = text
	frame.texture = texture

	return frame
end