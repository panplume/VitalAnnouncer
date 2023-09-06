VitalAnnouncer = {};

--VitalAnnouncerPCDB
local defaults = {
  enabled = true,
  reportKick = true,
  spells = {}, --dynamic based on preference [spellName]=true/false
  kicks = {}, --dynamic based on preference [spellName]=true/false
  chat = "SAY",
  chan = nil, --unused for "SAY"
}

local f = CreateFrame("frame", "VitalAnnouncer", UIParent)
f.panelSetupDone = false

SLASH_VITALANNOUNCER1 = "/vitalannouncer"
SLASH_VITALANNOUNCER2 = "/va"
SlashCmdList.VITALANNOUNCER = function(msg, editBox)
  local s1, s2 = strsplit(" ", msg)
  if #s1 > 0 then
    s1 = s1.lower()
    if s1 == "reset" then
      VitalAnnouncerPCDB = CopyTable(defaults)
      f.db = VitalAnnouncerPCDB
    elseif s1 == "active" then
      f.db.enable = not f.db.enable
      print("Reporting is globally "..f.db.reportKick)
    elseif s1 == "interrupt" then
      f.db.reportKick = not f.db.reportKick
      print("Reporting interrupt is now "..f.db.reportKick)
    elseif s1 == "say" then
      f.db.chat = "SAY"
      f.db.chan = nil --unused
    elseif s1 == "whisper" then
      f.db.chat = "WHISPER"
      if #s2 > 0 then
	f.db.chan = s2
      else
	f.db.chan = UnitName("player")
      end
    elseif s1 == "channel" then
      if #s2 > 0 then
	f.db.chat = "CHANNEL"
	f.db.chan = GetChannelName(s2)
      else
	print("Provide a channel name like \"General\" or \"CustomChan\" (no space allowed in channel name)")
	print(" /va channel UwUwarrior (join before, /join UwUwarrior)")
      end
    else
      print("VA: report important spells (missing debuff, interrupt)")
      print(" /va say|whisper|channel <channel/player name>")
      print(" /va active|interrupt (toggle whole addon/interrupt reporting)")
      print(" /va reset (return all value to defaults)")
      print(" /va (vanilla will open the option panel to choose spells)")
      print("ex:")
      print(" /va say")
      print(" /va whisper "..UnitName("player").." (default to whispering yourself)")
      print(" /va channel UwUwarrior (join before, /join UwUwarrior)")
    end
  else
    InterfaceOptionsFrame_OpenToCategory("VitalAnnouncer")
  end
end

--vitalSpells will report miss
--kickSpells will report successfull interrupt

local vitalSpells = {
  ["DRUID"] = {
    6795, --Growl
    --33876, 33982, 33983, --Mangle (Cat) if on Mangle duty
    33878, 33986, 33987, --Mangle (Bear)
    6807, 6808, 6809, 8972, 9745, 9880, 9881, 26996, --Maul
    5211, 6798, 8983, --Bash
    33786, --Cyclone
    22570, --Maim
  },
  ["HUNTER"] = {
    1499, 14310, 14311, --Freezing Trap
    1513, 14326, 14327, --Scare Beast
    19801, --Tranquilizing Shot
    19577, --Intimidation
    19386, 24132, 24133, 27068, --Wyvern Sting
    19503, --Scatter Shot
  },
  ["MAGE"] = {
    30449, --Spellsteal
    118, 12824, 12825, 12826, 28271, 28272, --Polymorph
  },
  ["PALADIN"] = {
    853, 5588, 5589, 10308, --Hammer of Justice
    31935, 32699, 32700, --Avengers Shield
    20066, --Repentance
  },
  ["PRIEST"] = {
    44041, 44043, 44044, 44045, 44046, 44047, --Chastise
    9484, 9485, 10955, --Shackle Undead
    605, 10911, 10912, --Mind Control
    8122, 8124, 10888, 10890, --Psychic Scream
  },
  ["ROGUE"] = {
    1833, --Cheap Shot
    408, 8643, --Kidney Shot
  },
  ["SHAMAN"] = {
  },
  ["WARRIOR"] = {
    1161, --Challenging Shout
    676, --Disarm
    694, 7400, 7402, 20559, 20560, 25266, --Mocking Blow
    355, --Taunt
    12809, --Concussion Blow
    23922, 23923, 23924, 23925, 25258, 30356, --Shield Slam
  },
  ["WARLOCK"] = {
    5782, 6213, 6215, --Fear
    1714, 11719, --Curse of Tongues
    710, 18647, --Banish
    1098, 11725, 11726, --Enslave Demon
    5484, 17928, --Howl of Terror
    6789, 17925, 17926, 27223, --Death Coil
    603, 30910, --Curse of Doom
    29858, --Soulshatter
    30283, 30413, 30414, --Shadowfury
    19505, 19731, 19734, 19736, 27276, 27277, --Devour Magic
  },
}

local kickSpells = {
  ["DRUID"] = {
    16979, --Feral Charge
  },
  ["HUNTER"] = {
    34490, --Silencing Shot
  },
  ["MAGE"] = {
    2139, --Counterspell
  },
  ["PALADIN"] = { --xD
  },
  ["PRIEST"] = {
    15487, --Silence
  },
  ["ROGUE"] = {
    1766, --Kick
  },
  ["SHAMAN"] = {
    8042, 8044, 8045, 8046, 10412, 10413, 10414, 25454, --Earth Shock
  },
  ["WARRIOR"] = {
    6552, 6554, --Pummel
    72, 1671, 1672, 29704, --Shield Bash
  },
  ["WARLOCK"] = {
    19244, 19647, --Spell Lock
  },
}

-- https://www.wowinterface.com/forums/showthread.php?t=39366
-- mark aren't reported in the flags outside raid
local function GetIconIndex(flags)
  local number, mask, mark
  if bit.band(flags, COMBATLOG_OBJECT_SPECIAL_MASK) ~= 0 then
    for i=1,8 do
      mask = COMBATLOG_OBJECT_RAIDTARGET1 * (2 ^ (i - 1))
      mark = bit.band(flags, mask) == mask
      if mark then number = i break end
    end
  end
  return number
end

local function updatePanelData(spellIDs)
  --input: spellID list
  --output: data[spellName] = { spellID (Rank i), ... }
  local data = {}
  for i=1, #spellIDs do
    name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange = GetSpellInfo(spellIDs[i])
    if data[name] then
      tinsert(data[name], spellIDs[i])
    else
      data[name] = { spellIDs[i] }
    end
  end
  
  return data
end

local function OnEvent(self, event, ...)
  if event == "ADDON_LOADED" then
    VitalAnnouncerPCDB = VitalAnnouncerPCDB or {}
    self.db = VitalAnnouncerPCDB
    for k, v in pairs(defaults) do
      if self.db[k] == nil then
	self.db[k] = v
      end
    end
    
    local _, class = UnitClass("player")
    --[spellName]={ids,...}
    self.spellIDs = updatePanelData(vitalSpells[class])
    self.kickIDs = updatePanelData(kickSpells[class])
    for k, v in pairs(self.spellIDs) do
      if self.db["spells"][k] == nil then --k = spell name
	self.db["spells"][k] = true --enable spell alert by default
      end
    end
    for k, v in pairs(self.kickIDs) do
      if self.db["kicks"][k] == nil then --k = spell name
	self.db["kicks"][k] = true --enable spell alert by default
      end
    end
    
    f:InitializeOptions()
    f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and f.db.enabled then
    local timestamp,e,uid,name,_,targetGUID,target,destFlags,sID,spell,_,reason = select(1,...)
    local playerID = UnitGUID("player")
    local petID = UnitGUID("pet")

    if e == "SPELL_CAST_SUCCESS" then
      --check kick
      --TODO:druid-maim with late PvP gloves, rogue-deadly throw with pvp gloves, rogue-stealth-garrote rank7/8
      for spellName, spellAnnounce in pairs(f.db["kicks"]) do
	if spellName == spell and spellAnnounce then
	  for _, unitID in pairs({"target", "focus"}) do
	    local guid = UnitGUID(unitID)
	    if guid == targetGUID then
	      --TODO: check notInterruptible
	      --name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unit)
	      kickedSpell=UnitCastingInfo(unitID) or UnitChannelInfo(unitID)
	      if kickedSpell then
		output = spell.." KICKED <"..target.."> "..kickedSpell
		SendChatMessage(output, f.db.chat, nil, f.db.chan)
		break
	      end
	    end
	  end
	  break
	end
      end
    elseif e == "SPELL_MISSED" and targetGUID == playerID and reason == "REFLECT" then
      output = name.." <"..spell.."> REFLECTED"
      SendChatMessage(output, f.db.chat, nil, f.db.chan)
    end
    if uid == playerID or uid == petID then
      if e == "SPELL_DISPEL" or e == "SPELL_DISPEL_FAILED" or e == "SPELL_STOLEN" then
	local dispellID, dispellName = select(12, ...)
	local status = " did something with "
	if e == "SPELL_DISPEL" then
	  status = " dispelled "
	elseif e == "SPELL_DISPEL_FAILED" then
	  status = " failed dispelling "
	elseif e == "SPELL_STOLEN" then
	  status = " stole "
	end
	output = spell..status..dispellName.." on "..target
	SendChatMessage(output, f.db.chat, nil, f.db.chan)
      elseif e == "SPELL_MISSED" then
	for k, v in pairs(f.db["spells"]) do
	  if spell == k and v then
	    --TODO: double check spellID in seld.spellIDs[spell]?
	    local mark = GetIconIndex(destFlags)
	    if mark ~= nil then
	      strMark = " {rt"..mark.."} "
	    else
	      strMark = " "
	    end
	    output = spell.." failed ("..reason..") on"..strMark..target..strMark
	    SendChatMessage(output, f.db.chat, nil, f.db.chan)
	    break
	  end
	end
      end
    end
  end
end

--build spell list in option panel
local function fillRow(frame, spellName, spellAnnounce, category)
  local spellCB = CreateFrame("CheckButton", "spellCB", frame, "InterfaceOptionsCheckButtonTemplate")
  spellCB:SetPoint("TOPLEFT", 20, 0)
  spellCB:SetChecked(spellAnnounce)
  spellCB:HookScript("OnClick",
     function(_, btn, down)
       f.db[category][spellName] = spellCB:GetChecked()
       if f.db[category][spellName] then
	 print("Announcing "..category.." "..spellName)
       else
	 print("Ignoring "..category.." "..spellName)
       end
  end)

  local buttonTexture = CreateFrame("Button", nil, frame)
  local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
  if f.spellIDs[spellName] then
    icon = select(3, GetSpellInfo(f.spellIDs[spellName][1]))
  elseif f.kickIDs[spellName] then
    icon = select(3, GetSpellInfo(f.kickIDs[spellName][1]))
  end
  buttonTexture:SetNormalTexture(icon)
  buttonTexture:SetSize(24, 24)
  buttonTexture:SetPoint("TOPLEFT", 48, 0)
  
  local spellNameFS = buttonTexture:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  spellNameFS:SetPoint("LEFT", 32, 0)
  spellNameFS:SetText(spellName)

  frame.columns = {} -- creating columns for the row
  frame.columns[1] = spellCB
  frame.columns[2] = buttonTexture
  frame.columns[3] = spellNameFS
end

--Draw a separator
local function fillSep(content, category)
  local frame = CreateFrame("frame", category.."SepFrame", content)
  frame:SetSize(content:GetWidth() - 20, 32)

  local label = CreateFrame("button", category.."Label", frame)
  label:SetPoint("TOPLEFT", 0, 0)
  label:SetPoint("BOTTOMRIGHT", frame:GetWidth(), 0)
  local categoryFS = label:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  categoryFS:SetPoint("TOPLEFT", 12, 0)
  categoryFS:SetText(category)

  local separator = CreateFrame("button", category.."HorizBar", frame)

  --https://github.com/Gethe/wow-ui-textures
  local texture = "Interface\\AchievementFrame\\UI-Achievement-MetalBorder-Top"
  separator:SetNormalTexture(texture)
  separator:SetSize(200, 3)
  separator:SetPoint("TOPLEFT", categoryFS:GetWidth() + 12, -10)

  return frame
end

local function updateList(content)
  --local data = f.db["spells"]
  --local content = f.panel.scrollFrame
  local i = 0
  for _, category in pairs({ "kicks", "spells" }) do
    local doSep = true
    for spellName, spellAnnounce in pairs(f.db[category]) do
      i = i + 1
      if doSep then
	local sep = fillSep(content, category)
	sep:SetPoint("TOPLEFT", 0, -(i-1) * 32)
	doSep = false
	i = i + 1
      end

      if not content.rows[i] then
	local frame = CreateFrame("frame", "row"..i, content)
	frame:SetSize(content:GetWidth() - 20, 32)
	frame:SetPoint("TOPLEFT", 0, -(i-1) * 32)
	content.rows[i] = frame
	fillRow(frame, spellName, spellAnnounce, category)
	content.rows[i]:Show()
      end
    end
  end
end

function f:InitializeOptions()
  if f.panelSetupDone then return end
  f.panelSetupDone = true
  self.panel = CreateFrame("Frame")
  self.panel.name = "VitalAnnouncer"

  --https://www.townlong-yak.com/framexml/3.3.5
  --Enable checkbox
  local enableCB = CreateFrame("CheckButton", "enableCB", self.panel, "InterfaceOptionsCheckButtonTemplate")
  enableCB:SetPoint("TOPLEFT", 20, -20)
  enableCBText:SetText("Enable")
  enableCB:HookScript("OnClick", function(_, btn, down)
			self.db.enabled = enableCB:GetChecked()
  end)
  enableCB:SetChecked(self.db.enabled)
  self.panel.enableCB = enableCB

  --reset options button
  local resetBTN = CreateFrame("Button", "resetBTN", self.panel, "UIPanelButtonTemplate")
  resetBTN:SetPoint("TOPRIGHT", -20, -20)
  resetBTN:SetText("Reset")
  resetBTN:SetSize(100,30)
  resetBTN:SetScript("OnClick", function(self)
		       --TODO clear scrollframe and repopulate it
		       VitalAnnouncerPCDB = CopyTable(defaults)
		       f.db = VitalAnnouncerPCDB
		       self:GetParent().enableCB:SetChecked(f.db.enabled)
		       self:GetParent().kickCB:SetChecked(f.db.reportKick)
		       self:GetParent().chatDD:SetValue(f.db.chat)
		       if f.db.chan ~= nil then
			 self:GetParent().chanEB:SetText(f.db.chan)
		       else
			 self:GetParent().chanEB:SetText("")
		       end
		       ReloadUI()
  end)

  --report kick checkbox
  local kickCB = CreateFrame("CheckButton", "kickCB", self.panel, "InterfaceOptionsCheckButtonTemplate")
  kickCB:SetPoint("BOTTOMRIGHT", enableCB, 0, -40)
  kickCBText:SetText("Interrupt")
  kickCB:HookScript("OnClick", function(_, btn, down)
			self.db.reportKick = kickCB:GetChecked()
  end)
  kickCB:SetChecked(self.db.reportKick)
  self.panel.kickCB = kickCB
  
  --report output choice
  local chatDD = CreateFrame("FRAME", "VAchat", self.panel, "UIDropDownMenuTemplate")
  self.panel.chatDD = chatDD
  chatDD:SetPoint("BOTTOMRIGHT", kickCB, 0, -40)
  --UIDropDownMenu_SetWidth(chatDD, 100)
  UIDropDownMenu_SetText(chatDD, "Output: "..f.db.chat)
  UIDropDownMenu_Initialize(chatDD,
    function(self, level, menuList)
      local info = UIDropDownMenu_CreateInfo()
      info.func = self.SetValue
      info.text, info.arg1, info.checked = "SAY", "SAY", false
      UIDropDownMenu_AddButton(info)
      info.text, info.arg1, info.checked = "WHISPER", "WHISPER", false
      UIDropDownMenu_AddButton(info)
      info.text, info.arg1, info.checked = "CHANNEL", "CHANNEL", false
      UIDropDownMenu_AddButton(info)
  end)
  function chatDD:SetValue(newValue)
    f.db.chat = newValue
    UIDropDownMenu_SetText(chatDD, "Output: "..f.db.chat)
    CloseDropDownMenus()
  end

  --TODO: add a label to the editbox
  --name to report to
  local chanEB = CreateFrame("EditBox", "chanEB", self.panel, "InputBoxTemplate")
  self.panel.chanEB = chanEB
  chanEB:SetPoint("TOP", chatDD, "TOP")
  chanEB:SetPoint("RIGHT", self.panel, "RIGHT", -20, 0)
  chanEB:SetAutoFocus(false)
  chanEB:SetSize(200,30)
  chanEB:SetMultiLine(false)
  --TODO:check empty name with WHISPER
  --TODO:check existing/joined channel?
  chanEB:SetScript("OnTextChanged", function(frame)
		     local self = frame.obj
		     local value = frame:GetText()
		     if #value > 0 then
		       f.db.chan = value
		     else
		       f.db.chan = nil
		     end
  end)
  if f.db.chan then
    chanEB:SetText(f.db.chan)
  end
  chanEB:SetCursorPosition(0)
  --chanEB:SetWidth(100)

  --https://www.wowinterface.com/forums/showthread.php?t=58670
  --spell list
  local scrollFrame = CreateFrame("ScrollFrame","scrollFrame",self.panel,"UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT",chatDD,"BOTTOMLEFT",12,-32)
  scrollFrame:SetPoint("BOTTOMRIGHT",-34,8)
  -- creating a scrollChild to contain the content
  scrollFrame.scrollChild = CreateFrame("Frame",nil,scrollFrame)
  scrollFrame.scrollChild:SetSize(100,100)
  scrollFrame.scrollChild:SetPoint("TOPLEFT",5,-5)
  scrollFrame:SetScrollChild(scrollFrame.scrollChild)
  -- adding content to the scrollChild
  scrollFrame.scrollChild.rows = {}
  self.panel.scrollFrame = scrollFrame
  updateList(self.panel.scrollFrame.scrollChild)

  InterfaceOptions_AddCategory(self.panel)
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnEvent)
