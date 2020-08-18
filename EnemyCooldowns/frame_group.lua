local engine = select(2,...)

local ICONS_SIZE = 24
local ICONS_AT_COLUMN = 4
local ICONS_MAX = 20
local OFFSET_Y = 2
local OFFSET_X = 22
local SPELLS = engine.SPELLS
local math = math
local table = engine.table
local next = next
local CreateFrame = CreateFrame

local prototype = setmetatable({},getmetatable(UIParent))
local MT = {__index = prototype}


local function sortFunc(a,b)
	return a.timeStamp < b.timeStamp
end

function prototype:Update(cooldownInfo)
	if not cooldownInfo then
		engine:ReleaseTracker(self.GUID)
		return
	end

	local m_icons = self.icons


	local cdList,n,t = table.new(),0
	for spellID,timeStamp in next,cooldownInfo do
		t = table.new()
		t.spellID = spellID
		t.timeStamp = timeStamp

		n = n + 1
		cdList[n] = t
	end
	table.sort(cdList,sortFunc)

	local icon,cd,spellID
	for i = 1,math.min(math.max(n,#m_icons),ICONS_MAX) do
		icon,cd = m_icons[i],cdList[i]

		if cd then
			if not icon then
				icon = engine:CreateIcon(self)
				icon:SetSize(ICONS_SIZE,ICONS_SIZE)
				icon:SetPoint("TOPLEFT",math.floor(((i-1)/ICONS_AT_COLUMN))*(ICONS_SIZE+OFFSET_X),-((i-1)%ICONS_AT_COLUMN)*(ICONS_SIZE+OFFSET_Y))

				m_icons[i] = icon
			end

			spellID = cd.spellID
			icon:SetSpell(spellID)
			icon:SetCooldown(cd.timeStamp,SPELLS[spellID])
		elseif icon and icon:IsShown() then
			icon:Hide()
		else
			break
		end
	end

	for i = 1,n do
		cdList[i] = table.del(cdList[i])
	end
	table.del(cdList)


	self:SetWidth(math.ceil((n/ICONS_AT_COLUMN))*(ICONS_SIZE+OFFSET_X))
end

function prototype:HideIcons()
	local m_icons,icon = self.icons
	for i = 1,#m_icons do
		icon = m_icons[i]

		if icon:IsShown() then
			icon:Hide()
		else
			break
		end
	end
end

function prototype:Initialize(GUID,unitName)
	self.name:SetText(unitName)
	self.GUID = GUID
	self:Show()
end

function prototype:Release()
	self.GUID = nil
	self:Hide()
end


function engine:CreateGroup()
	local frame = setmetatable(CreateFrame("frame",nil,UIParent),MT)
	frame:SetHeight(1)

	local name = frame:CreateFontString(nil,"BORDER","NumberFontNormal")
	name:SetPoint("BOTTOM",frame,"TOP",0,2)


	frame.name = name
	frame.icons = {}

	return frame
end