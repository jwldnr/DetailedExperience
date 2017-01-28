local Addon = {}
Addon.name = "DetailedExperience"

local GetWindowManager = GetWindowManager
local WINDOW_MANAGER = GetWindowManager()

local GetEventManager = GetEventManager
local EVENT_MANAGER = GetEventManager()

local GetAnimationManager = GetAnimationManager
local ANIMATION_MANAGER = GetAnimationManager()

local SCENE_MANAGER = SCENE_MANAGER

local EVENT_ADD_ON_LOADED = EVENT_ADD_ON_LOADED
local EVENT_PLAYER_ACTIVATED = EVENT_PLAYER_ACTIVATED

local PLAYER_PROGRESS_BAR = PLAYER_PROGRESS_BAR
local PLAYER_PROGRESS_BAR_FRAGMENT = PLAYER_PROGRESS_BAR_FRAGMENT
local PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT = PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT
local CHAT_SYSTEM = CHAT_SYSTEM

local strformat = string.format
local pairs = pairs

local GetUnitXP = GetUnitXP
local GetUnitXPMax = GetUnitXPMax

local IsUnitChampion = IsUnitChampion
local GetPlayerChampionXP = GetPlayerChampionXP
local GetUnitChampionPoints = GetUnitChampionPoints
local GetNumChampionXPInChampionPoint = GetNumChampionXPInChampionPoint
local GetChampionPointsPlayerProgressionCap = GetChampionPointsPlayerProgressionCap

local CT_LABEL = CT_LABEL
local RIGHT = RIGHT
local TEXT_ALIGN_RIGHT = TEXT_ALIGN_RIGHT
local TEXT_ALIGN_CENTER = TEXT_ALIGN_CENTER

local ANIMATION_COLOR = ANIMATION_COLOR

local ZO_PreHookHandler = ZO_PreHookHandler

local SI_EXPERIENCE_LIMIT_REACHED = SI_EXPERIENCE_LIMIT_REACHED

local PROGRESS_SCENE_FRAGMENTS = { "hud", "hudui", "interact" }

local function GetProgressText(current, max)
  max = max > 0 and max or 1
  return strformat("%d / %d (%d%%)", current, max, (current / max) * 100)
end

local function ShouldShowProgressBar()
  return true
end

local function GetPlayerXP()
  if (IsUnitChampion("player")) then
    return GetPlayerChampionXP()
  end

  return GetUnitXP("player")
end

local function GetPlayerXPMax()
  if (IsUnitChampion("player")) then
    local playerChampionPoints = GetUnitChampionPoints("player")
    local maxRank = GetChampionPointsPlayerProgressionCap()

    if (playerChampionPoints == maxRank) then
      return GetNumChampionXPInChampionPoint(maxRank)
    end

    return GetNumChampionXPInChampionPoint(playerChampionPoints)
  end

  return GetUnitXPMax("player")
end

function Addon:OnPlayerActivated()
  EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_PLAYER_ACTIVATED)

  local color = ZO_ColorDef:New(1, .7, 1)
  CHAT_SYSTEM:AddMessage(color:Colorize(self.name.." loaded"))
end

function Addon:UpdateProgressLabel()
  local barTypeInfo = PLAYER_PROGRESS_BAR:GetBarTypeInfo()
  if (not barTypeInfo) then return end

  local level = barTypeInfo:GetLevel()
  local levelSize = barTypeInfo:GetLevelSize(level)

  if (not levelSize) then
    self.progressLabel:SetText(GetProgressText(1, 1))
    return
  end

  local current = barTypeInfo:GetCurrent()
  if (not current) then return end

  if (current == levelSize) then
    self.progressLabel:SetText(GetString(SI_EXPERIENCE_LIMIT_REACHED))
  else
    self.progressLabel:SetText(GetProgressText(current, levelSize))
  end
end

function Addon:OnPlayProgressBarFade(timeline)
  if (timeline:IsPlayingBackward()) then return end

  self:UpdateProgressLabel()
end

function Addon:Initialize()
  for _, v in pairs(PROGRESS_SCENE_FRAGMENTS) do
    local scene = SCENE_MANAGER:GetScene(v)
    scene:AddFragment(PLAYER_PROGRESS_BAR_FRAGMENT)
    scene:AddFragment(PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT)
  end

  PLAYER_PROGRESS_BAR_FRAGMENT:SetConditional(ShouldShowProgressBar)
  PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT:SetConditional(ShouldShowProgressBar)

  self.control = PLAYER_PROGRESS_BAR.control
  self.barControl = self.control:GetNamedChild("Bar")

  self.progressLabel = WINDOW_MANAGER:CreateControl("DetailedExperienceProgress", self.control, CT_LABEL)
  self.progressLabel:SetAnchor(RIGHT, self.barControl, RIGHT, -5, 20)
  self.progressLabel:SetFont("ZoFontGameBold")
  self.progressLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  self.progressLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

  self.progressAnimation = ANIMATION_MANAGER:CreateTimeline()

  local toGreen = self.progressAnimation:InsertAnimation(ANIMATION_COLOR, self.progressLabel)
  toGreen:SetDuration(400)
  toGreen:SetColorValues(1, 1, 1, 1, .7, 1, .7, 1)

  local toWhite = self.progressAnimation:InsertAnimation(ANIMATION_COLOR, self.progressLabel, 400)
  toWhite:SetDuration(400)
  toWhite:SetColorValues(.7, 1, .7, 1, 1, 1, 1, 1)
end

function Addon:PlayProgressLabelAnimation()
  if (self.progressAnimation:IsPlaying()) then return end
  self.progressAnimation:PlayFromStart()
end

do
  local oSetBarValue = PLAYER_PROGRESS_BAR.SetBarValue

  local function SetBarValue(self, level, current)
    oSetBarValue(self, level, current)
    Addon:UpdateProgressLabel()
    Addon:PlayProgressLabelAnimation()
  end

  local function OnPlayProgressBarFade(timeline)
    Addon:OnPlayProgressBarFade(timeline)
  end

  function Addon:HookPlayerProgressBar()
    PLAYER_PROGRESS_BAR.SetBarValue = SetBarValue

    ZO_PreHookHandler(PLAYER_PROGRESS_BAR.fadeTimeline, "OnPlay", OnPlayProgressBarFade)
  end
end

function Addon:OnAddOnLoaded(name)
  if (name ~= self.name) then return end

  EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)

  self:Initialize()
  self:RegisterForEvents()
  self:HookPlayerProgressBar()
end

do
  local function OnAddOnLoaded(event, ...)
    Addon:OnAddOnLoaded(...)
  end

  local function OnPlayerActivated(event, ...)
    Addon:OnPlayerActivated(...)
  end

  function Addon:Load()
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
  end

  function Addon:RegisterForEvents()
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
  end
end

Addon:Load()
