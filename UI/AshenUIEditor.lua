-- RedLobsterCult / Red Lobster Cult main UI size editor
-- Kept separate from Core.lua to avoid Vanilla Lua local limits.

function RLC_DumpMainUISize()
  local f = RLC and RLC.UI and RLC.UI.frame
  if not f then
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700RLCUI:|r main frame not built yet") end
    return
  end
  local scale = 1
  if RLC_DB and RLC_DB.ui and RLC_DB.ui.scale then scale = RLC_DB.ui.scale end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700RLCUI:|r w=" .. tostring(math.floor(f:GetWidth() or 0)) .. " h=" .. tostring(math.floor(f:GetHeight() or 0)) .. " scale=" .. tostring(scale))
  end
end

function RLC_ApplyMainUISize(w, h)
  if not RLC or not RLC.ApplyUISize then return end
  RLC:ApplyUISize(w, h)
  if RLC_RefreshAshenBG then RLC_RefreshAshenBG() end
  RLC_DumpMainUISize()
end

function RLC_NudgeMainUISize(dw, dh)
  local f = RLC and RLC.UI and RLC.UI.frame
  if not f then return end
  local w = (f:GetWidth() or 1050) + (dw or 0)
  local h = (f:GetHeight() or 760) + (dh or 0)
  RLC_ApplyMainUISize(w, h)
end

function RLC_SetMainUISizeFromMsg(msg)
  local _, _, a, b = string.find(msg or "", "(-?%d+)%s+(-?%d+)")
  if a and b then
    RLC_ApplyMainUISize(tonumber(a), tonumber(b))
  else
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700RLCUI:|r usage: /abuisize width height") end
  end
end

function RLC_NudgeMainUIScale(ds)
  if not RLC or not RLC.ApplyUIScale then return end
  local cur = 1
  if RLC_DB and RLC_DB.ui and RLC_DB.ui.scale then cur = RLC_DB.ui.scale end
  RLC:ApplyUIScale(cur + (ds or 0))
  if RLC_RefreshAshenBG then RLC_RefreshAshenBG() end
  RLC_DumpMainUISize()
end

function RLC_SetMainUIScaleFromMsg(msg)
  local s = tonumber(msg or "")
  if s then
    RLC:ApplyUIScale(s)
    if RLC_RefreshAshenBG then RLC_RefreshAshenBG() end
    RLC_DumpMainUISize()
  else
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700RLCUI:|r usage: /abuiscale 0.85") end
  end
end

function RLC_FitMainUIToAshenBG()
  local c = RLC_GetAshenBGLayout and RLC_GetAshenBGLayout()
  if not c then return end
  local tw = tonumber(c.tileW) or 137
  local th = tonumber(c.tileH) or 92
  -- Fit width to the full 8-tile background. Height remains at least the addon minimum.
  local w = tw * 8
  local h = th * 4
  if RLC and RLC.uiMinHeight and h < RLC.uiMinHeight then h = RLC.uiMinHeight end
  RLC_ApplyMainUISize(w, h)
end

function RLC_CreateMainUIEditor()
  if RLC_MainUIEditor and RLC_MainUIEditor:IsVisible() then
    RLC_MainUIEditor:Hide()
    return
  end

  local f = RLC_MainUIEditor
  if not f then
    f = CreateFrame("Frame", "RLC_MainUIEditor", UIParent)
    RLC_MainUIEditor = f
    f:SetWidth(260)
    f:SetHeight(230)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:SetBackdropBorderColor(0.8, 0.55, 0.2, 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetText("RLC UI Size")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

    local function Btn(txt, x, y, fn)
      local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
      b:SetWidth(70); b:SetHeight(22); b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
      b:SetText(txt); b:SetScript("OnClick", fn); return b
    end
    local function Label(txt, y)
      local l = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      l:SetPoint("TOPLEFT", f, "TOPLEFT", 12, y); l:SetText(txt); return l
    end

    Label("Frame Width", -40)
    Btn("W -", 95, -36, function() RLC_NudgeMainUISize(-20, 0) end)
    Btn("W +", 170, -36, function() RLC_NudgeMainUISize(20, 0) end)

    Label("Frame Height", -72)
    Btn("H -", 95, -68, function() RLC_NudgeMainUISize(0, -20) end)
    Btn("H +", 170, -68, function() RLC_NudgeMainUISize(0, 20) end)

    Label("UI Scale", -104)
    Btn("S -", 95, -100, function() RLC_NudgeMainUIScale(-0.02) end)
    Btn("S +", 170, -100, function() RLC_NudgeMainUIScale(0.02) end)

    Btn("Fit BG", 12, -140, RLC_FitMainUIToAshenBG)
    Btn("Dump", 95, -140, RLC_DumpMainUISize)
    Btn("BG Dump", 170, -140, function() if RLC_DumpAshenBG then RLC_DumpAshenBG() end end)
  end
  f:Show()
  RLC_DumpMainUISize()
end

local function GuardedMainUIEditor() if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then Print("|cFFFF4444Access denied: Red Lobster Cult is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.|r") return end RLC_CreateMainUIEditor() end
local function GuardedSetUISize(msg) if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then Print("|cFFFF4444Access denied: Red Lobster Cult is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.|r") return end RLC_SetMainUISizeFromMsg(msg) end
local function GuardedSetUIScale(msg) if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then Print("|cFFFF4444Access denied: Red Lobster Cult is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.|r") return end RLC_SetMainUIScaleFromMsg(msg) end
local function GuardedDumpUISize() if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then Print("|cFFFF4444Access denied: Red Lobster Cult is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.|r") return end RLC_DumpMainUISize() end
local function GuardedFitUIToBG() if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then Print("|cFFFF4444Access denied: Red Lobster Cult is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.|r") return end RLC_FitMainUIToAshenBG() end

SLASH_RLC_UIEDITOR1 = "/abuieditor"
SlashCmdList["RLC_UIEDITOR"] = GuardedMainUIEditor

SLASH_RLC_UISIZE1 = "/abuisize"
SlashCmdList["RLC_UISIZE"] = GuardedSetUISize

SLASH_RLC_UISCALE1 = "/abuiscale"
SlashCmdList["RLC_UISCALE"] = GuardedSetUIScale

SLASH_RLC_UIDUMP1 = "/abuidump"
SlashCmdList["RLC_UIDUMP"] = GuardedDumpUISize

SLASH_RLC_UIFITBG1 = "/abuifitbg"
SlashCmdList["RLC_UIFITBG"] = GuardedFitUIToBG
