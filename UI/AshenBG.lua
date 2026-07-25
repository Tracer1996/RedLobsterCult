-- RedLobsterCult / Red Lobster Cult tiled main background
-- Kept out of Core.lua so Vanilla Lua 5.0 does not hit the 200 local variable limit.

ASHEN_BG_TILE_ROWS = 4
ASHEN_BG_TILE_COLS = 4

function RLC_GetAshenBGLayout()
  RLC_AshenBGLayout = RLC_AshenBGLayout or {}
  if RLC_AshenBGLayout.__layoutVersion ~= 2 then
    RLC_AshenBGLayout.x = 0
    RLC_AshenBGLayout.y = 0
    RLC_AshenBGLayout.w = 0
    RLC_AshenBGLayout.h = 0
    RLC_AshenBGLayout.tileW = 0
    RLC_AshenBGLayout.tileH = 0
    RLC_AshenBGLayout.alpha = 1
    RLC_AshenBGLayout.__layoutVersion = 2
  end
  if RLC_AshenBGLayout.x == nil then RLC_AshenBGLayout.x = 0 end
  if RLC_AshenBGLayout.y == nil then RLC_AshenBGLayout.y = 0 end
  if RLC_AshenBGLayout.w == nil then RLC_AshenBGLayout.w = 0 end
  if RLC_AshenBGLayout.h == nil then RLC_AshenBGLayout.h = 0 end
  if RLC_AshenBGLayout.tileW == nil then RLC_AshenBGLayout.tileW = 0 end
  if RLC_AshenBGLayout.tileH == nil then RLC_AshenBGLayout.tileH = 0 end
  if RLC_AshenBGLayout.alpha == nil then RLC_AshenBGLayout.alpha = 1 end
  return RLC_AshenBGLayout
end

function RLC_CreateAshenTileBackground(parent)
  if not parent then return end

  local cfg = RLC_GetAshenBGLayout()
  if not parent.ashenBgTiles then parent.ashenBgTiles = {} end

  if not parent._ashenBgHolder then
    parent._ashenBgHolder = CreateFrame("Frame", nil, parent)
    if parent._ashenBgHolder.SetFrameLevel and parent.GetFrameLevel then
      parent._ashenBgHolder:SetFrameLevel((parent:GetFrameLevel() or 1) + 1)
    end
  end

  local pw = parent:GetWidth() or 928
  local ph = parent:GetHeight() or 820
  if pw < 1 then pw = 928 end
  if ph < 1 then ph = 820 end

  local holderW = pw + (cfg.w or 0)
  local holderH = ph + (cfg.h or 0)
  local autoTileW = holderW / ASHEN_BG_TILE_COLS
  local autoTileH = holderH / ASHEN_BG_TILE_ROWS
  local tileW, tileH, totalW, totalH, offsetX, offsetY

  parent._ashenBgHolder:ClearAllPoints()
  parent._ashenBgHolder:SetPoint("TOPLEFT", parent, "TOPLEFT", cfg.x or 0, cfg.y or 0)
  parent._ashenBgHolder:SetWidth(holderW)
  parent._ashenBgHolder:SetHeight(holderH)
  parent._ashenBgHolder:Show()

  -- Default mode anchors/scales the tiled background to the current UI frame.
  -- Use /abbgtile w h only if you intentionally want manual tile sizing.
  if cfg.tileW and cfg.tileW ~= 0 then tileW = cfg.tileW else tileW = autoTileW end
  if cfg.tileH and cfg.tileH ~= 0 then tileH = cfg.tileH else tileH = autoTileH end

  parent._ashenBgTileW = tileW
  parent._ashenBgTileH = tileH
  totalW = tileW * ASHEN_BG_TILE_COLS
  totalH = tileH * ASHEN_BG_TILE_ROWS
  offsetX = math.floor((holderW - totalW) / 2)
  offsetY = math.floor((holderH - totalH) / 2)
  parent._ashenBgOffsetX = offsetX
  parent._ashenBgOffsetY = offsetY

  local row, col, i, tex, suffix
  for row = 1, ASHEN_BG_TILE_ROWS do
    for col = 1, ASHEN_BG_TILE_COLS do
      i = ((row - 1) * ASHEN_BG_TILE_COLS) + col
      tex = parent.ashenBgTiles[i]
      if not tex then
        tex = parent._ashenBgHolder:CreateTexture(nil, "BACKGROUND")
        parent.ashenBgTiles[i] = tex
      end

      suffix = tostring(i)
      if i < 10 then suffix = "0" .. suffix end

      tex:ClearAllPoints()
      tex:SetTexture("Interface\\AddOns\\RedLobsterCult\\Textures\\RLC_BG_" .. suffix)
      tex:SetTexCoord(0, 1, 0, 1)
      tex:SetWidth((tileW or 157) + 1)
      tex:SetHeight((tileH or 157) + 1)

      if row == 1 and col == 1 then
        tex:SetPoint("TOPLEFT", parent._ashenBgHolder, "TOPLEFT", offsetX, offsetY)
      elseif col == 1 then
        tex:SetPoint("TOPLEFT", parent.ashenBgTiles[((row - 2) * ASHEN_BG_TILE_COLS) + 1], "BOTTOMLEFT", 0, 0)
      else
        tex:SetPoint("TOPLEFT", parent.ashenBgTiles[i - 1], "TOPRIGHT", 0, 0)
      end

      tex:SetVertexColor(1, 1, 1, cfg.alpha or 1)
      tex:Show()
    end
  end

  for i = 17, 64 do
    if parent.ashenBgTiles[i] then parent.ashenBgTiles[i]:Hide() end
  end
end

function RLC_RefreshAshenBG()
  if RLC and RLC.UI and RLC.UI.frame then
    RLC_CreateAshenTileBackground(RLC.UI.frame)
  end
end

function RLC_DumpAshenBG()
  local c = RLC_GetAshenBGLayout()
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700RLCBG:|r x=" .. tostring(c.x or 0) .. " y=" .. tostring(c.y or 0) .. " w=" .. tostring(c.w or 0) .. " h=" .. tostring(c.h or 0) .. " tileW=" .. tostring(c.tileW or 0) .. " tileH=" .. tostring(c.tileH or 0) .. " alpha=" .. tostring(c.alpha or 1))
  end
end

function RLC_NudgeAshenBG(field, amount)
  local c = RLC_GetAshenBGLayout()
  c[field] = (tonumber(c[field]) or 0) + amount
  RLC_RefreshAshenBG()
  RLC_DumpAshenBG()
end

function RLC_ResetAshenBG()
  RLC_AshenBGLayout = { x = 0, y = 0, w = 0, h = 0, tileW = 0, tileH = 0, alpha = 1, __layoutVersion = 2 }
  RLC_RefreshAshenBG()
  RLC_DumpAshenBG()
end

function RLC_SetAshenBGFromMsg(msg, fieldA, fieldB)
  local _, _, a, b = string.find(msg or "", "(-?%d+)%s+(-?%d+)")
  local c = RLC_GetAshenBGLayout()
  if a then c[fieldA] = tonumber(a) or 0 end
  if b then c[fieldB] = tonumber(b) or 0 end
  RLC_RefreshAshenBG()
  RLC_DumpAshenBG()
end


function RLC_NudgeAshenBGScale(dw, dh)
  local c = RLC_GetAshenBGLayout()
  local f = RLC and RLC.UI and RLC.UI.frame
  local curW = tonumber(c.tileW) or 0
  local curH = tonumber(c.tileH) or 0
  if curW == 0 then
    if f and f._ashenBgTileW then curW = math.floor(f._ashenBgTileW) else curW = 157 end
  end
  if curH == 0 then
    if f and f._ashenBgTileH then curH = math.floor(f._ashenBgTileH) else curH = 157 end
  end
  curW = curW + (dw or 0)
  curH = curH + (dh or 0)
  if curW < 48 then curW = 48 end
  if curH < 48 then curH = 48 end
  c.tileW = curW
  c.tileH = curH
  RLC_RefreshAshenBG()
  RLC_DumpAshenBG()
end

function RLC_SetAshenBGScaleFromMsg(msg)
  local _, _, a, b = string.find(msg or "", "(-?%d+)%s*(-?%d*)")
  if not a then return end
  local n1 = tonumber(a)
  local n2 = tonumber(b)
  local c = RLC_GetAshenBGLayout()
  if n1 and n2 then
    c.tileW = n1
    c.tileH = n2
  elseif n1 then
    c.tileW = n1
    c.tileH = n1
  end
  RLC_RefreshAshenBG()
  RLC_DumpAshenBG()
end

function RLC_CreateAshenBGEditor()
  if RLC_AshenBGEditor and RLC_AshenBGEditor:IsVisible() then
    RLC_AshenBGEditor:Hide()
    return
  end

  local f = RLC_AshenBGEditor
  if not f then
    f = CreateFrame("Frame", "RLC_AshenBGEditor", UIParent)
    RLC_AshenBGEditor = f
    f:SetWidth(250)
    f:SetHeight(315)
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
    title:SetText("RLC BG Editor")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

    local function MakeBtn(txt, x, y, field, amt)
      local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
      b:SetWidth(52)
      b:SetHeight(22)
      b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
      b:SetText(txt)
      b:SetScript("OnClick", function() RLC_NudgeAshenBG(field, amt) end)
      return b
    end

    local function MakeLabel(txt, y)
      local l = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      l:SetPoint("TOPLEFT", f, "TOPLEFT", 12, y)
      l:SetText(txt)
      return l
    end

    MakeLabel("Move", -38)
    MakeBtn("X-", 70, -34, "x", -10); MakeBtn("X+", 126, -34, "x", 10); MakeBtn("Y+", 182, -34, "y", 10)
    MakeBtn("Y-", 182, -58, "y", -10)

    MakeLabel("Size", -88)
    MakeBtn("W-", 70, -84, "w", -20); MakeBtn("W+", 126, -84, "w", 20)
    MakeBtn("H-", 70, -108, "h", -20); MakeBtn("H+", 126, -108, "h", 20)

    MakeLabel("Tile", -138)
    MakeBtn("TW-", 70, -134, "tileW", -5); MakeBtn("TW+", 126, -134, "tileW", 5)
    MakeBtn("TH-", 70, -158, "tileH", -5); MakeBtn("TH+", 126, -158, "tileH", 5)

    MakeLabel("Overall Scale", -188)
    local scaleDown = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scaleDown:SetWidth(80); scaleDown:SetHeight(22); scaleDown:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -184)
    scaleDown:SetText("Scale -")
    scaleDown:SetScript("OnClick", function() RLC_NudgeAshenBGScale(-8, -8) end)

    local scaleUp = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scaleUp:SetWidth(80); scaleUp:SetHeight(22); scaleUp:SetPoint("LEFT", scaleDown, "RIGHT", 8, 0)
    scaleUp:SetText("Scale +")
    scaleUp:SetScript("OnClick", function() RLC_NudgeAshenBGScale(8, 8) end)

    local dump = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    dump:SetWidth(70); dump:SetHeight(24); dump:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 14); dump:SetText("Dump")
    dump:SetScript("OnClick", RLC_DumpAshenBG)

    local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reset:SetWidth(70); reset:SetHeight(24); reset:SetPoint("LEFT", dump, "RIGHT", 8, 0); reset:SetText("Reset")
    reset:SetScript("OnClick", RLC_ResetAshenBG)

    local refresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refresh:SetWidth(70); refresh:SetHeight(24); refresh:SetPoint("LEFT", reset, "RIGHT", 8, 0); refresh:SetText("Refresh")
    refresh:SetScript("OnClick", RLC_RefreshAshenBG)
  end
  f:Show()
  RLC_RefreshAshenBG()
end

SLASH_RLC_BGDEBUG1 = "/abbgdebug"
SlashCmdList["RLC_BGDEBUG"] = function()
  if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF4444Access denied: Red Lobster Cult is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.|r")
    return
  end
  local f = RLC and RLC.UI and RLC.UI.frame
  if not f then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700RLCBG:|r main frame not built yet")
    return
  end
  RLC_CreateAshenTileBackground(f)
  DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700RLCBG:|r using 8x4 safe ROOT tiles, aspect-correct")
  DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700RLCBG:|r holder=" .. math.floor(f._ashenBgHolder:GetWidth() or 0) .. "x" .. math.floor(f._ashenBgHolder:GetHeight() or 0) .. " tile=" .. math.floor(f._ashenBgTileW or 0) .. "x" .. math.floor(f._ashenBgTileH or 0) .. " offset=" .. tostring(f._ashenBgOffsetX or 0) .. "," .. tostring(f._ashenBgOffsetY or 0))
  if f.ashenBgTiles and f.ashenBgTiles[1] and f.ashenBgTiles[1].GetTexture then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700RLCBG:|r first tile=" .. tostring(f.ashenBgTiles[1]:GetTexture()))
  end
  RLC_DumpAshenBG()
end

local function GuardedCreateAshenBGEditor() if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then DEFAULT_CHAT_FRAME:AddMessage("|cFFFF4444Access denied: Red Lobster Cult is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.|r") return end RLC_CreateAshenBGEditor() end
local function GuardedDumpAshenBG() if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then DEFAULT_CHAT_FRAME:AddMessage("|cFFFF4444Access denied: Red Lobster Cult is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.|r") return end RLC_DumpAshenBG() end
local function GuardedSetAshenBGScaleFromMsg(msg) if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then DEFAULT_CHAT_FRAME:AddMessage("|cFFFF4444Access denied: Red Lobster Cult is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.|r") return end RLC_SetAshenBGScaleFromMsg(msg) end

SLASH_RLC_BGEDITOR1 = "/abbgeditor"
SlashCmdList["RLC_BGEDITOR"] = GuardedCreateAshenBGEditor

SLASH_RLC_BGDUMP1 = "/abbgdump"
SlashCmdList["RLC_BGDUMP"] = GuardedDumpAshenBG

SLASH_RLC_BGMOVE1 = "/abbgmove"
SlashCmdList["RLC_BGMOVE"] = function(msg) if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then DEFAULT_CHAT_FRAME:AddMessage("|cFFFF4444Access denied: Red Lobster Cult is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.|r") return end RLC_SetAshenBGFromMsg(msg, "x", "y") end

SLASH_RLC_BGSIZE1 = "/abbgsize"
SlashCmdList["RLC_BGSIZE"] = function(msg) if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then DEFAULT_CHAT_FRAME:AddMessage("|cFFFF4444Access denied: Red Lobster Cult is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.|r") return end RLC_SetAshenBGFromMsg(msg, "w", "h") end

SLASH_RLC_BGTILE1 = "/abbgtile"
SlashCmdList["RLC_BGTILE"] = function(msg) if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then DEFAULT_CHAT_FRAME:AddMessage("|cFFFF4444Access denied: Red Lobster Cult is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.|r") return end RLC_SetAshenBGFromMsg(msg, "tileW", "tileH") end

SLASH_RLC_BGSCALE1 = "/abbgscale"
SlashCmdList["RLC_BGSCALE"] = GuardedSetAshenBGScaleFromMsg
