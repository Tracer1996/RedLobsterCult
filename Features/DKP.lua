RLC = RLC or {}
RLC.DKP = RLC.DKP or {}

local DKP = RLC.DKP

DKP.VERSION = 2
DKP.CAP = 5000
DKP.MAX_HISTORY = 5000
DKP.SYNC_HISTORY_LIMIT = 80
DKP.WIRE_SEPARATOR = string.char(31)
DKP.pages = DKP.pages or {}
DKP.messageQueue = DKP.messageQueue or {}
DKP.messageElapsed = 0
DKP.serial = DKP.serial or 0
DKP.widgetSerial = DKP.widgetSerial or 0

DKP.CLASS_COLORS = {
  WARRIOR = "FFC79C6E",
  PALADIN = "FFF58CBA",
  HUNTER = "FFABD473",
  ROGUE = "FFFFF569",
  PRIEST = "FFFFFFFF",
  SHAMAN = "FF0070DE",
  MAGE = "FF69CCF0",
  WARLOCK = "FF9482C9",
  DRUID = "FFFF7D0A",
}

DKP.PRESETS = {
  { label = "Level 60", amount = 250, reason = "Reached level 60" },
  { label = "Attunement", amount = 100, reason = "Raid attunement" },
  { label = "Boss Kill", amount = 100, reason = "Current raid boss kill" },
  { label = "Dungeon", amount = 10, reason = "3/5 guild dungeon run" },
  { label = "Mechanic", amount = 10, reason = "Special raid mechanic" },
  { label = "MC Douser", amount = 50, reason = "Molten Core douser" },
  { label = "Donation", amount = 5, reason = "Useful material donation" },
  { label = "Off-Spec", amount = 10, reason = "Off-spec swap for the raid" },
  { label = "Failure", amount = -10, reason = "Three mechanic failures" },
}

local function DKPPrint(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFE45B24Red Lobster Cult DKP|r: " .. tostring(message or ""))
  end
end

local function ShortName(name)
  if not name then return nil end
  local dash = string.find(name, "-", 1, true)
  if dash then
    return string.sub(name, 1, dash - 1)
  end
  return name
end

local function Lower(value)
  return string.lower(tostring(value or ""))
end

local function Trim(value)
  return string.gsub(tostring(value or ""), "^%s*(.-)%s*$", "%1")
end

local function Clamp(value, minimum, maximum)
  value = tonumber(value) or 0
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function RoundInteger(value)
  value = tonumber(value) or 0
  if value >= 0 then
    return math.floor(value + 0.5)
  end
  return math.ceil(value - 0.5)
end

local function SafeText(value, maximumLength)
  local text = tostring(value or "")
  text = string.gsub(text, "|", "/")
  text = string.gsub(text, DKP.WIRE_SEPARATOR, " ")
  text = string.gsub(text, "[\r\n]", " ")
  text = Trim(text)
  if maximumLength and string.len(text) > maximumLength then
    text = string.sub(text, 1, maximumLength)
  end
  return text
end

local function SplitMessage(message, separator)
  local fields = {}
  local startAt = 1
  local messageLength = string.len(message or "")
  while startAt <= messageLength + 1 do
    local divider = string.find(message, separator, startAt, true)
    if divider then
      table.insert(fields, string.sub(message, startAt, divider - 1))
      startAt = divider + 1
    else
      table.insert(fields, string.sub(message, startAt))
      break
    end
  end
  return fields
end

local function SplitWire(message)
  if string.find(message or "", DKP.WIRE_SEPARATOR, 1, true) then
    return SplitMessage(message, DKP.WIRE_SEPARATOR)
  end
  -- Accept v19.8 messages from a peer long enough for a rolling guild update.
  return SplitMessage(message, "|")
end

local function JoinWire(fields)
  return table.concat(fields, DKP.WIRE_SEPARATOR)
end

local function ActiveGuildContext()
  local guildName = GetGuildInfo and GetGuildInfo("player") or nil
  guildName = Trim(guildName)
  if guildName == "" then
    return nil, "__no_guild__"
  end

  local realmName = GetRealmName and GetRealmName() or ""
  realmName = Trim(realmName)
  return guildName, Lower(realmName .. "::" .. guildName)
end

local function CopyRecord(source)
  local copy = {}
  if type(source) == "table" then
    for key, value in pairs(source) do
      copy[key] = value
    end
  end
  return copy
end

local function IsInGuild()
  if _G.IsInGuild then
    return _G.IsInGuild()
  end
  if GetGuildInfo then
    return GetGuildInfo("player") ~= nil
  end
  return false
end

local function InRaid()
  return GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0
end

local function NextWidgetName(kind)
  DKP.widgetSerial = (DKP.widgetSerial or 0) + 1
  return "RLC_DKP_" .. tostring(kind or "Widget") .. "_" .. tostring(DKP.widgetSerial)
end

local function ClassColoredName(name, classToken)
  local color = DKP.CLASS_COLORS[string.upper(tostring(classToken or ""))] or "FFFFFFFF"
  return "|c" .. color .. tostring(name or "Unknown") .. "|r"
end

local function SetDarkBackdrop(frame, alpha)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(0.035, 0.02, 0.015, alpha or 0.96)
  frame:SetBackdropBorderColor(0.82, 0.29, 0.08, 0.95)
end

local function BringDKPOverlayToFront(frame)
  if not frame then return end
  if frame.SetToplevel then frame:SetToplevel(true) end
  if frame.SetFrameStrata then frame:SetFrameStrata("FULLSCREEN_DIALOG") end
  if frame.SetFrameLevel then frame:SetFrameLevel(500) end
  frame:Show()
  if frame.Raise then frame:Raise() end
end

local function MakeButton(parent, text, width, height)
  local button = CreateFrame("Button", NextWidgetName("Button"), parent, "UIPanelButtonTemplate")
  button:SetWidth(width or 72)
  button:SetHeight(height or 22)
  button:SetText(text or "")
  local fontString = button.GetFontString and button:GetFontString()
  if fontString then
    fontString:SetTextColor(1, 0.82, 0.42)
  end
  return button
end

local function MakeLabel(parent, text, fontObject)
  local label = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
  label:SetText(text or "")
  return label
end

function DKP:MigrateLegacyData(root, db, guildKey, guildName)
  local legacy = root and root.legacyV1
  if type(legacy) ~= "table" or not guildName or guildKey == "__no_guild__" then
    return
  end
  if type(legacy.migratedGuilds) ~= "table" then legacy.migratedGuilds = {} end
  if legacy.migratedGuilds[guildKey] then return end
  if self.rosterReadyGuildKey ~= guildKey then return end

  local activeMembers = {}
  if SetGuildRosterShowOffline then SetGuildRosterShowOffline(true) end
  local memberCount = GetNumGuildMembers and (GetNumGuildMembers() or 0) or 0
  if memberCount <= 0 then return end
  for index = 1, memberCount do
    local name = GetGuildRosterInfo(index)
    name = ShortName(name)
    if name and name ~= "" then
      activeMembers[Lower(name)] = true
    end
  end

  for key, record in pairs(legacy.balances or {}) do
    local recordName = type(record) == "table" and record.name or key
    local memberKey = Lower(ShortName(recordName))
    if activeMembers[memberKey] then
      db.balances[memberKey] = CopyRecord(record)
      db.balances[memberKey].name = ShortName(recordName)
    end
  end

  for index = 1, table.getn(legacy.transactions or {}) do
    local transaction = legacy.transactions[index]
    local memberKey = transaction and Lower(ShortName(transaction.name))
    if memberKey and activeMembers[memberKey] then
      local copiedTransaction = CopyRecord(transaction)
      table.insert(db.transactions, copiedTransaction)
      if copiedTransaction.id then
        db.seenTransactions[copiedTransaction.id] = true
      end
    end
  end

  legacy.migratedGuilds[guildKey] = time()
  db.legacyImportedAt = time()
end

function DKP:EnsureDB()
  RLC_GlobalDB = RLC_GlobalDB or {}
  RLC_DB = RLC_DB or {}

  if type(RLC_GlobalDB.dkp) ~= "table" then
    RLC_GlobalDB.dkp = {}
  end
  local root = RLC_GlobalDB.dkp

  -- v19.8 stored every guild in one flat ledger. Preserve that ledger as an
  -- archive, then import only names confirmed in the active live guild roster.
  if type(root.guilds) ~= "table" then root.guilds = {} end
  if (type(root.balances) == "table" or type(root.transactions) == "table")
      and type(root.legacyV1) ~= "table" then
    root.legacyV1 = {
      balances = root.balances or {},
      transactions = root.transactions or {},
      seenTransactions = root.seenTransactions or {},
      migratedGuilds = {},
    }
  end
  root.balances = nil
  root.transactions = nil
  root.seenTransactions = nil
  root.version = self.VERSION
  root.cap = self.CAP

  local guildName, guildKey = ActiveGuildContext()
  if self.activeGuildKey ~= guildKey then
    self.activeGuildKey = guildKey
    self.activeGuildName = guildName
    self.rosterReadyGuildKey = nil
    self.messageQueue = {}
  end

  if type(root.guilds[guildKey]) ~= "table" then
    root.guilds[guildKey] = {}
  end
  local db = root.guilds[guildKey]
  if type(db.balances) ~= "table" then db.balances = {} end
  if type(db.transactions) ~= "table" then db.transactions = {} end
  if type(db.seenTransactions) ~= "table" then db.seenTransactions = {} end
  db.version = self.VERSION
  db.cap = self.CAP
  db.guildName = guildName
  db.guildKey = guildKey
  self:MigrateLegacyData(root, db, guildKey, guildName)

  if type(RLC_DB.dkpUI) ~= "table" then RLC_DB.dkpUI = {} end
  if type(RLC_DB.dkpUI.window) ~= "table" then RLC_DB.dkpUI.window = {} end
  if type(RLC_DB.dkpUI.compact) ~= "table" then RLC_DB.dkpUI.compact = {} end

  local window = RLC_DB.dkpUI.window
  if not window.tab then window.tab = "roster" end
  if not window.scale then window.scale = 1 end

  local compact = RLC_DB.dkpUI.compact
  if compact.scale == nil then compact.scale = 0.90 end
  if compact.locked == nil then compact.locked = false end
  if compact.visible == nil then compact.visible = false end
  if compact.layoutVersion ~= 2 then
    compact.width = 220
    compact.height = 82
    compact.userSized = false
    compact.layoutVersion = 2
  end
  compact.width = Clamp(compact.width or 220, 190, 420)
  compact.height = Clamp(compact.height or 82, 74, 650)

  return db
end

function DKP:GetActiveGuild()
  local guildName, guildKey = ActiveGuildContext()
  return guildName, guildKey
end

function DKP:RequestGuildRoster(force)
  local guildName, guildKey = ActiveGuildContext()
  if not guildName then return end
  local now = time()
  if force or self.lastRosterRequestGuildKey ~= guildKey
      or (now - (self.lastRosterRequestAt or 0)) >= 5 then
    self.lastRosterRequestGuildKey = guildKey
    self.lastRosterRequestAt = now
    if SetGuildRosterShowOffline then SetGuildRosterShowOffline(true) end
    if GuildRoster then GuildRoster() end
  end
end

function DKP:MarkGuildRosterReady()
  self:EnsureDB()
  local guildName, guildKey = ActiveGuildContext()
  if not guildName then
    self.rosterReadyGuildKey = nil
    return
  end
  self.rosterReadyGuildKey = guildKey
  -- Run the filtered v19.8 migration only after this guild's live roster is ready.
  self:EnsureDB()
end

function DKP:GetDB()
  return self:EnsureDB()
end

function DKP:IsCurrentGuildMember(playerName)
  local nameKey = Lower(ShortName(playerName))
  if nameKey == "" then return false end
  local guildName, guildKey = ActiveGuildContext()
  if not guildName or self.rosterReadyGuildKey ~= guildKey then return false end

  if SetGuildRosterShowOffline then SetGuildRosterShowOffline(true) end
  local memberCount = GetNumGuildMembers and (GetNumGuildMembers() or 0) or 0
  for index = 1, memberCount do
    local rosterName = ShortName(GetGuildRosterInfo(index))
    if rosterName and Lower(rosterName) == nameKey then
      return true
    end
  end
  return false
end

function DKP:GetBalance(playerName)
  local db = self:EnsureDB()
  local key = Lower(ShortName(playerName))
  local record = db.balances[key]
  if not record then return 0 end
  return Clamp(RoundInteger(record.balance), 0, self.CAP)
end

function DKP:GetBalanceRecord(playerName)
  local db = self:EnsureDB()
  return db.balances[Lower(ShortName(playerName))]
end

function DKP:NextTransactionID()
  self.serial = (self.serial or 0) + 1
  local actor = SafeText(ShortName(UnitName("player")) or "Unknown", 20)
  return actor .. "-" .. tostring(time()) .. "-" .. string.format("%06d", self.serial)
end

function DKP:TrimHistory()
  local db = self:EnsureDB()
  while table.getn(db.transactions) > self.MAX_HISTORY do
    local removed = table.remove(db.transactions, 1)
    if removed and removed.id then
      db.seenTransactions[removed.id] = nil
    end
  end
end

function DKP:StoreTransaction(transaction, fromSync)
  if type(transaction) ~= "table" or not transaction.id or not transaction.name then
    return false
  end
  if fromSync and not self:IsCurrentGuildMember(transaction.name) then
    return false
  end

  local db = self:EnsureDB()
  if db.seenTransactions[transaction.id] then
    return false
  end

  transaction.name = ShortName(transaction.name)
  transaction.actor = ShortName(transaction.actor) or "Unknown"
  transaction.timestamp = tonumber(transaction.timestamp) or time()
  transaction.before = Clamp(RoundInteger(transaction.before), 0, self.CAP)
  transaction.after = Clamp(RoundInteger(transaction.after), 0, self.CAP)
  transaction.amount = RoundInteger(transaction.amount)
  transaction.operation = transaction.operation == "SET" and "SET" or "ADD"
  transaction.reason = SafeText(transaction.reason, 80)

  db.seenTransactions[transaction.id] = true
  table.insert(db.transactions, transaction)
  self:TrimHistory()

  local key = Lower(transaction.name)
  local current = db.balances[key]
  local currentTimestamp = current and tonumber(current.updatedAt) or 0
  local shouldApply = not current
    or transaction.timestamp > currentTimestamp
    or (transaction.timestamp == currentTimestamp and tostring(transaction.id) > tostring(current.transactionId or ""))

  if shouldApply then
    db.balances[key] = {
      name = transaction.name,
      balance = transaction.after,
      updatedAt = transaction.timestamp,
      updatedBy = transaction.actor,
      transactionId = transaction.id,
    }
  end

  self:RefreshAll()
  if not fromSync then
    self:BroadcastTransaction(transaction)
  end
  return true
end

function DKP:ApplyChange(playerName, operation, amount, reason, silent)
  if not RLC or not RLC.IsAdminRank or not RLC:IsAdminRank() then
    if not silent then
      DKPPrint("Access denied: only Tong Bender, Leviathan, or Tracerboy can modify DKP.")
    end
    return false, "Access denied."
  end

  local name = ShortName(Trim(playerName))
  if not name or name == "" then
    return false, "No character selected."
  end

  operation = operation == "SET" and "SET" or "ADD"
  amount = RoundInteger(amount)
  local before = self:GetBalance(name)
  local after
  if operation == "SET" then
    after = Clamp(amount, 0, self.CAP)
  else
    after = Clamp(before + amount, 0, self.CAP)
  end

  if after == before and operation ~= "SET" then
    if not silent then
      if amount > 0 and before >= self.CAP then
        DKPPrint(name .. " is already at the 5,000 DKP cap.")
      elseif amount < 0 and before <= 0 then
        DKPPrint(name .. " is already at 0 DKP.")
      end
    end
    return false, "Balance did not change."
  end

  local actor = ShortName(UnitName("player")) or "Unknown"
  local transaction = {
    id = self:NextTransactionID(),
    operation = operation,
    name = name,
    amount = operation == "SET" and after or amount,
    before = before,
    after = after,
    timestamp = time(),
    actor = actor,
    reason = SafeText(reason ~= "" and reason or "Manual adjustment", 80),
  }

  self:StoreTransaction(transaction, false)
  if not silent then
    if operation == "SET" then
      DKPPrint(name .. " set to " .. tostring(after) .. " DKP.")
    else
      local applied = after - before
      local prefix = applied >= 0 and "+" or ""
      DKPPrint(name .. " " .. prefix .. tostring(applied) .. " DKP. New balance: " .. tostring(after) .. ".")
    end
  end
  return true, transaction
end

function DKP:ApplyChangeToPlayers(playerNames, operation, amount, reason)
  local changed = 0
  for i = 1, table.getn(playerNames or {}) do
    local didChange = self:ApplyChange(playerNames[i], operation, amount, reason, true)
    if didChange then changed = changed + 1 end
  end
  DKPPrint("Updated " .. tostring(changed) .. " character" .. (changed == 1 and "" or "s") .. ".")
  return changed
end

function DKP:GetRosterMembers()
  if SetGuildRosterShowOffline then SetGuildRosterShowOffline(true) end
  local db = self:EnsureDB()
  local membersByKey = {}
  local guildName, guildKey = ActiveGuildContext()
  if not guildName then return {} end
  if self.rosterReadyGuildKey ~= guildKey then
    self:RequestGuildRoster(false)
    return {}
  end

  local totalGuildMembers = GetNumGuildMembers and (GetNumGuildMembers() or 0) or 0
  for index = 1, totalGuildMembers do
    local name, rank, rankIndex, level, class, zone, note, officerNote, online = GetGuildRosterInfo(index)
    name = ShortName(name)
    if name and name ~= "" then
      membersByKey[Lower(name)] = {
        name = name,
        class = class or "",
        rank = rank or "",
        level = level or 0,
        online = online and true or false,
      }
    end
  end

  local members = {}
  for key, member in pairs(membersByKey) do
    member.balance = self:GetBalance(member.name)
    member.balanceRecord = db.balances[key]
    table.insert(members, member)
  end

  table.sort(members, function(a, b)
    if a.balance == b.balance then
      return Lower(a.name) < Lower(b.name)
    end
    return a.balance > b.balance
  end)
  return members
end

function DKP:GetRaidMembers()
  local members = {}
  local count = GetNumRaidMembers and (GetNumRaidMembers() or 0) or 0
  for index = 1, count do
    local name, rank, subgroup, level, class, classToken, zone, online, isDead = GetRaidRosterInfo(index)
    name = ShortName(name)
    if name and name ~= "" then
      table.insert(members, {
        index = index,
        name = name,
        rank = rank or 0,
        subgroup = subgroup or 0,
        level = level or 0,
        class = class or "",
        classToken = classToken or class or "",
        zone = zone or "",
        online = online and true or false,
        dead = isDead and true or false,
        balance = self:GetBalance(name),
      })
    end
  end

  table.sort(members, function(a, b)
    if a.subgroup == b.subgroup then
      return Lower(a.name) < Lower(b.name)
    end
    return a.subgroup < b.subgroup
  end)
  return members
end

function DKP:GetRaidNames()
  local names = {}
  local members = self:GetRaidMembers()
  for i = 1, table.getn(members) do
    table.insert(names, members[i].name)
  end
  return names
end

function DKP:QueueMessage(message)
  if not message or message == "" then return end
  table.insert(self.messageQueue, message)
  if self.messageFrame then self.messageFrame:Show() end
end

function DKP:SendMessageNow(message)
  if not SendAddonMessage or not IsInGuild() then return end
  -- A raw pipe is a chat escape character on Turtle WoW. DKP v2 uses the
  -- addon-safe ASCII unit separator so ChatThrottleLib never sees bad escapes.
  message = string.gsub(tostring(message or ""), "|", "/")
  SendAddonMessage("RLC", message, "GUILD")
end

function DKP:BroadcastTransaction(transaction)
  local message = JoinWire({
    "DKPTXN",
    SafeText(transaction.id, 40),
    transaction.operation == "SET" and "SET" or "ADD",
    SafeText(transaction.name, 20),
    tostring(transaction.amount or 0),
    tostring(transaction.before or 0),
    tostring(transaction.after or 0),
    tostring(transaction.timestamp or time()),
    SafeText(transaction.actor, 20),
    SafeText(transaction.reason, 70),
  })
  self:QueueMessage(message)
end

function DKP:RequestSync()
  if not IsInGuild() then
    DKPPrint("You must be in the guild to request DKP synchronization.")
    return
  end
  local me = ShortName(UnitName("player")) or "Unknown"
  local nonce = tostring(time()) .. "-" .. tostring(math.random(1000, 9999))
  self:SendMessageNow(JoinWire({"DKPREQ", SafeText(me, 20), nonce}))
  DKPPrint("DKP synchronization requested.")
end

function DKP:CanAnswerSync()
  if RLC and type(RLC.IsAdminRank) == "function" then
    local ok, allowed = pcall(RLC.IsAdminRank, RLC)
    if ok and allowed then return true end
  end
  return false
end

function DKP:SendSyncTo(requester)
  if not self:CanAnswerSync() then return end
  local db = self:EnsureDB()
  local target = SafeText(ShortName(requester), 20)
  local me = SafeText(ShortName(UnitName("player")) or "Unknown", 20)
  self:QueueMessage(JoinWire({"DKPBEGIN", target, me}))

  local states = {}
  for _, record in pairs(db.balances) do
    if self:IsCurrentGuildMember(record.name) then
      table.insert(states, record)
    end
  end
  table.sort(states, function(a, b)
    return Lower(a.name) < Lower(b.name)
  end)

  for i = 1, table.getn(states) do
    local record = states[i]
    self:QueueMessage(JoinWire({
      "DKPSTATE",
      target,
      SafeText(record.name, 20),
      tostring(record.balance or 0),
      tostring(record.updatedAt or 0),
      SafeText(record.updatedBy, 20),
      SafeText(record.transactionId, 40),
    }))
  end

  local firstHistory = math.max(1, table.getn(db.transactions) - self.SYNC_HISTORY_LIMIT + 1)
  for index = firstHistory, table.getn(db.transactions) do
    local transaction = db.transactions[index]
    if self:IsCurrentGuildMember(transaction.name) then
      self:QueueMessage(JoinWire({
        "DKPLOG",
        target,
        SafeText(transaction.id, 40),
        transaction.operation == "SET" and "SET" or "ADD",
        SafeText(transaction.name, 20),
        tostring(transaction.amount or 0),
        tostring(transaction.before or 0),
        tostring(transaction.after or 0),
        tostring(transaction.timestamp or 0),
        SafeText(transaction.actor, 20),
        SafeText(transaction.reason, 60),
      }))
    end
  end
  self:QueueMessage(JoinWire({"DKPEND", target, me}))
end

function DKP:BroadcastSnapshot()
  if not self:CanAnswerSync() then return end
  local db = self:EnsureDB()
  local me = SafeText(ShortName(UnitName("player")) or "Unknown", 20)
  self:QueueMessage(JoinWire({"DKPSNAPBEGIN", me}))

  local states = {}
  for _, record in pairs(db.balances) do
    if self:IsCurrentGuildMember(record.name) then
      table.insert(states, record)
    end
  end
  table.sort(states, function(a, b) return Lower(a.name) < Lower(b.name) end)

  for i = 1, table.getn(states) do
    local record = states[i]
    self:QueueMessage(JoinWire({
      "DKPSNAP",
      SafeText(record.name, 20),
      tostring(record.balance or 0),
      tostring(record.updatedAt or 0),
      SafeText(record.updatedBy, 20),
      SafeText(record.transactionId, 40),
    }))
  end

  local firstHistory = math.max(1, table.getn(db.transactions) - self.SYNC_HISTORY_LIMIT + 1)
  for index = firstHistory, table.getn(db.transactions) do
    local transaction = db.transactions[index]
    if self:IsCurrentGuildMember(transaction.name) then
      self:QueueMessage(JoinWire({
        "DKPSNAPLOG",
        SafeText(transaction.id, 40),
        transaction.operation == "SET" and "SET" or "ADD",
        SafeText(transaction.name, 20),
        tostring(transaction.amount or 0),
        tostring(transaction.before or 0),
        tostring(transaction.after or 0),
        tostring(transaction.timestamp or 0),
        SafeText(transaction.actor, 20),
        SafeText(transaction.reason, 60),
      }))
    end
  end
  self:QueueMessage(JoinWire({"DKPSNAPEND", me}))
end

function DKP:RequestSnapshot()
  if not IsInGuild() then return end
  local me = ShortName(UnitName("player")) or "Unknown"
  local nonce = tostring(time()) .. "-" .. tostring(math.random(1000, 9999))
  self:SendMessageNow(JoinWire({"DKPSNAPREQ", SafeText(me, 20), nonce}))
  DKPPrint("DKP snapshot requested.")
end

function DKP:ReceiveSnapshot(fields)
  local name = ShortName(fields[2])
  if not name or name == "" then return end
  if not self:IsCurrentGuildMember(name) then return end
  local incomingTimestamp = tonumber(fields[4]) or 0
  local db = self:EnsureDB()
  local key = Lower(name)
  local current = db.balances[key]
  local currentTimestamp = current and tonumber(current.updatedAt) or 0
  if not current or incomingTimestamp > currentTimestamp then
    db.balances[key] = {
      name = name,
      balance = Clamp(RoundInteger(tonumber(fields[3]) or 0), 0, self.CAP),
      updatedAt = incomingTimestamp,
      updatedBy = ShortName(fields[5]) or "Sync",
      transactionId = fields[6] or "",
    }
    self:RefreshAll()
  end
end

function DKP:ReceiveTransaction(fields, fromLog)
  local offset = fromLog and 1 or 0
  local transaction = {
    id = fields[2 + offset],
    operation = fields[3 + offset],
    name = fields[4 + offset],
    amount = tonumber(fields[5 + offset]) or 0,
    before = tonumber(fields[6 + offset]) or 0,
    after = tonumber(fields[7 + offset]) or 0,
    timestamp = tonumber(fields[8 + offset]) or 0,
    actor = fields[9 + offset],
    reason = fields[10 + offset],
  }
  self:StoreTransaction(transaction, true)
end

function DKP:ReceiveState(fields)
  local me = Lower(ShortName(UnitName("player")))
  if Lower(ShortName(fields[2])) ~= me then return end

  local name = ShortName(fields[3])
  if not name or name == "" then return end
  if not self:IsCurrentGuildMember(name) then return end
  local incomingTimestamp = tonumber(fields[5]) or 0
  local db = self:EnsureDB()
  local key = Lower(name)
  local current = db.balances[key]
  local currentTimestamp = current and tonumber(current.updatedAt) or 0
  if not current or incomingTimestamp > currentTimestamp then
    db.balances[key] = {
      name = name,
      balance = Clamp(RoundInteger(fields[4]), 0, self.CAP),
      updatedAt = incomingTimestamp,
      updatedBy = ShortName(fields[6]) or "Sync",
      transactionId = fields[7] or "",
    }
    self:RefreshAll()
  end
end

function DKP:HandleAddonMessage(prefix, message, sender)
  if prefix ~= "RLC" or type(message) ~= "string" then return end
  if string.sub(message, 1, 3) ~= "DKP" then return end
  if not sender then return end

  local fields = SplitWire(message)
  local kind = fields[1]
  local me = Lower(ShortName(UnitName("player")))
  local from = Lower(ShortName(sender))
  local isSenderAdmin = RLC and RLC.IsAdminRank and RLC:IsAdminRank(ShortName(sender))

  if kind == "DKPTXN" then
    if from ~= me and isSenderAdmin then self:ReceiveTransaction(fields, false) end
  elseif kind == "DKPREQ" then
    local requester = ShortName(fields[2])
    if requester and Lower(requester) ~= me then
      self:SendSyncTo(requester)
    end
  elseif kind == "DKPSTATE" then
    if isSenderAdmin then self:ReceiveState(fields) end
  elseif kind == "DKPLOG" then
    if Lower(ShortName(fields[2])) == me and isSenderAdmin then
      self:ReceiveTransaction(fields, true)
    end
  elseif kind == "DKPSNAPREQ" then
    if isSenderAdmin then
      DKPPrint("DKP snapshot requested by " .. tostring(ShortName(fields[2]) or "a guildie") .. ".")
      self:BroadcastSnapshot()
    end
  elseif kind == "DKPSNAP" then
    if isSenderAdmin then self:ReceiveSnapshot(fields) end
  elseif kind == "DKPSNAPLOG" then
    if isSenderAdmin then
      local transaction = {
        id = fields[2],
        operation = fields[3],
        name = fields[4],
        amount = tonumber(fields[5]) or 0,
        before = tonumber(fields[6]) or 0,
        after = tonumber(fields[7]) or 0,
        timestamp = tonumber(fields[8]) or 0,
        actor = fields[9],
        reason = fields[10],
      }
      self:StoreTransaction(transaction, true)
    end
  elseif kind == "DKPSNAPBEGIN" then
    if isSenderAdmin then
      DKPPrint("Receiving DKP snapshot from " .. tostring(ShortName(fields[2]) or "an officer") .. "...")
    end
  elseif kind == "DKPEND" then
    if Lower(ShortName(fields[2])) == me and isSenderAdmin then
      DKPPrint("DKP synchronization complete.")
      self:RefreshAll()
    end
  elseif kind == "DKPSNAPEND" then
    if isSenderAdmin then
      DKPPrint("DKP snapshot complete.")
      self:RefreshAll()
    end
  end
end

function DKP:CreateAdjustDialog()
  if self.adjustDialog then return self.adjustDialog end

  local frame = CreateFrame("Frame", "RLC_DKP_AdjustDialog", UIParent)
  frame:SetWidth(390)
  frame:SetHeight(245)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetFrameLevel(500)
  if frame.SetToplevel then frame:SetToplevel(true) end
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  SetDarkBackdrop(frame, 0.98)
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  frame:Hide()

  local title = MakeLabel(frame, "DKP Adjustment", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -14)
  title:SetTextColor(1, 0.75, 0.25)
  frame.title = title

  local target = MakeLabel(frame, "", "GameFontHighlight")
  target:SetPoint("TOP", title, "BOTTOM", 0, -9)
  target:SetWidth(350)
  target:SetJustifyH("CENTER")
  frame.targetText = target

  local amountLabel = MakeLabel(frame, "Amount", "GameFontNormal")
  amountLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -82)

  local amountBox = CreateFrame("EditBox", NextWidgetName("AmountBox"), frame, "InputBoxTemplate")
  amountBox:SetWidth(120)
  amountBox:SetHeight(24)
  amountBox:SetPoint("LEFT", amountLabel, "RIGHT", 22, 0)
  amountBox:SetAutoFocus(false)
  amountBox:SetNumeric(true)
  frame.amountBox = amountBox

  local reasonLabel = MakeLabel(frame, "Reason", "GameFontNormal")
  reasonLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -122)

  local reasonBox = CreateFrame("EditBox", NextWidgetName("ReasonBox"), frame, "InputBoxTemplate")
  reasonBox:SetWidth(270)
  reasonBox:SetHeight(24)
  reasonBox:SetPoint("LEFT", reasonLabel, "RIGHT", 20, 0)
  reasonBox:SetAutoFocus(false)
  frame.reasonBox = reasonBox

  local confirm = MakeButton(frame, "Confirm", 104, 25)
  confirm:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -8, 18)
  confirm:SetScript("OnClick", function()
    local dialog = RLC.DKP.adjustDialog
    local amount = tonumber(dialog.amountBox:GetText() or "")
    if not amount then
      DKPPrint("Enter a DKP amount.")
      return
    end
    amount = math.abs(RoundInteger(amount))
    if dialog.operation == "DEDUCT" then
      amount = -amount
    end
    if dialog.operation == "SET" then
      amount = Clamp(amount, 0, RLC.DKP.CAP)
    end
    if dialog.operation ~= "SET" and amount == 0 then
      DKPPrint("The adjustment amount cannot be zero.")
      return
    end
    local operation = dialog.operation == "SET" and "SET" or "ADD"
    local reason = Trim(dialog.reasonBox:GetText() or "")
    RLC.DKP:ApplyChangeToPlayers(dialog.targets or {}, operation, amount, reason)
    dialog:Hide()
  end)

  local cancel = MakeButton(frame, "Cancel", 104, 25)
  cancel:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 8, 18)
  cancel:SetScript("OnClick", function() RLC.DKP.adjustDialog:Hide() end)

  frame.amountBox:SetScript("OnEnterPressed", function() confirm:Click() end)
  frame.amountBox:SetScript("OnEscapePressed", function() frame:Hide() end)
  frame.reasonBox:SetScript("OnEnterPressed", function() confirm:Click() end)
  frame.reasonBox:SetScript("OnEscapePressed", function() frame:Hide() end)

  self.adjustDialog = frame
  return frame
end

function DKP:OpenAdjustDialog(playerOrPlayers, operation, defaultAmount, reason, title)
  if not RLC or not RLC.IsAdminRank or not RLC:IsAdminRank() then
    DKPPrint("Access denied: only Tong Bender, Leviathan, or Tracerboy can modify DKP.")
    return
  end

  local targets = {}
  if type(playerOrPlayers) == "table" then
    for i = 1, table.getn(playerOrPlayers) do
      local name = ShortName(playerOrPlayers[i])
      if name and name ~= "" then table.insert(targets, name) end
    end
  else
    local name = ShortName(playerOrPlayers)
    if name and name ~= "" then table.insert(targets, name) end
  end

  if table.getn(targets) < 1 then
    DKPPrint("No characters are available for this adjustment.")
    return
  end

  local dialog = self:CreateAdjustDialog()
  dialog.targets = targets
  dialog.operation = operation or "ADD"
  dialog.title:SetText(title or "DKP Adjustment")
  if table.getn(targets) == 1 then
    dialog.targetText:SetText(ClassColoredName(targets[1]) .. "  |cFFFFD700" .. tostring(self:GetBalance(targets[1])) .. " DKP|r")
  else
    dialog.targetText:SetText("|cFFFFD700" .. tostring(table.getn(targets)) .. " current raid members|r")
  end
  dialog.amountBox:SetText(defaultAmount and tostring(math.abs(defaultAmount)) or "")
  dialog.reasonBox:SetText(reason or "")
  BringDKPOverlayToFront(dialog)
  dialog.amountBox:SetFocus()
  dialog.amountBox:HighlightText()
end

function DKP:OpenIndividualAction(playerName, operation)
  local labels = {
    ADD = "Add DKP",
    DEDUCT = "Deduct DKP",
    SET = "Set DKP Balance",
  }
  self:OpenAdjustDialog(playerName, operation, nil, "Manual adjustment", labels[operation] or "DKP Adjustment")
end

function DKP:OpenRaidPreset(preset)
  if not InRaid() then
    DKPPrint("You are not currently in a raid.")
    return
  end
  local operation = preset.amount < 0 and "DEDUCT" or "ADD"
  self:OpenAdjustDialog(self:GetRaidNames(), operation, math.abs(preset.amount), preset.reason, preset.label .. " - Entire Raid")
end

function DKP:CreateExportFrame()
  if self.exportFrame then return self.exportFrame end

  local frame = CreateFrame("Frame", "RLC_DKP_ExportFrame", UIParent)
  frame:SetWidth(720)
  frame:SetHeight(520)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetFrameLevel(500)
  if frame.SetToplevel then frame:SetToplevel(true) end
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  SetDarkBackdrop(frame, 0.99)
  frame:Hide()

  local title = MakeLabel(frame, "DKP Export", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -14)
  title:SetTextColor(1, 0.75, 0.25)
  frame.title = title

  local help = MakeLabel(frame, "Press Ctrl+C to copy the selected data.", "GameFontHighlightSmall")
  help:SetPoint("TOP", title, "BOTTOM", 0, -5)
  help:SetTextColor(0.75, 0.75, 0.75)

  local scroll = CreateFrame("ScrollFrame", NextWidgetName("ExportScroll"), frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -62)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 52)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetWidth(650)
  edit:SetHeight(400)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal)
  edit:SetTextInsets(5, 5, 5, 5)
  edit:SetScript("OnEscapePressed", function() frame:Hide() end)
  scroll:SetScrollChild(edit)
  frame.editBox = edit

  local close = MakeButton(frame, "Close", 110, 25)
  close:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
  close:SetScript("OnClick", function() frame:Hide() end)

  self.exportFrame = frame
  return frame
end

function DKP:ShowExport(mode)
  local frame = self:CreateExportFrame()
  local lines = {}
  if mode == "history" then
    frame.title:SetText("DKP Transaction Log")
    table.insert(lines, "Timestamp\tCharacter\tOperation\tAmount\tBefore\tAfter\tReason\tOfficer\tTransaction ID")
    local db = self:EnsureDB()
    for index = table.getn(db.transactions), 1, -1 do
      local transaction = db.transactions[index]
      table.insert(lines, table.concat({
        date("%Y-%m-%d %H:%M:%S", transaction.timestamp or 0),
        transaction.name or "",
        transaction.operation or "",
        tostring(transaction.amount or 0),
        tostring(transaction.before or 0),
        tostring(transaction.after or 0),
        SafeText(transaction.reason, 120),
        transaction.actor or "",
        transaction.id or "",
      }, "\t"))
    end
  else
    frame.title:SetText("DKP Roster Export")
    table.insert(lines, "Rank\tCharacter\tClass\tDKP\tLast Updated\tUpdated By")
    local members = self:GetRosterMembers()
    for index = 1, table.getn(members) do
      local member = members[index]
      local record = member.balanceRecord
      table.insert(lines, table.concat({
        tostring(index),
        member.name or "",
        member.class or "",
        tostring(member.balance or 0),
        record and date("%Y-%m-%d %H:%M:%S", record.updatedAt or 0) or "",
        record and tostring(record.updatedBy or "") or "",
      }, "\t"))
    end
  end
  frame.editBox:SetText(table.concat(lines, "\n"))
  frame.editBox:SetHeight(math.max(400, table.getn(lines) * 14))
  BringDKPOverlayToFront(frame)
  frame.editBox:SetFocus()
  frame.editBox:HighlightText()
end

function DKP:CreateRosterRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(25)
  row:SetPoint("LEFT", parent, "LEFT", 0, 0)
  row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

  local background = row:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(row)
  background:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  background:SetVertexColor(0.16, 0.075, 0.035, 0.58)
  row.background = background

  local rank = MakeLabel(row, "", "GameFontHighlightSmall")
  rank:SetPoint("LEFT", row, "LEFT", 7, 0)
  rank:SetWidth(32)
  rank:SetJustifyH("RIGHT")
  row.rankText = rank

  local name = MakeLabel(row, "", "GameFontHighlight")
  name:SetPoint("LEFT", row, "LEFT", 50, 0)
  name:SetWidth(185)
  name:SetJustifyH("LEFT")
  row.nameText = name

  local class = MakeLabel(row, "", "GameFontHighlightSmall")
  class:SetPoint("LEFT", row, "LEFT", 240, 0)
  class:SetWidth(105)
  class:SetJustifyH("LEFT")
  row.classText = class

  local balance = MakeLabel(row, "", "GameFontNormal")
  balance:SetPoint("LEFT", row, "LEFT", 355, 0)
  balance:SetWidth(95)
  balance:SetJustifyH("RIGHT")
  balance:SetTextColor(1, 0.82, 0.28)
  row.balanceText = balance

  local updated = MakeLabel(row, "", "GameFontHighlightSmall")
  updated:SetPoint("LEFT", row, "LEFT", 468, 0)
  updated:SetWidth(215)
  updated:SetJustifyH("LEFT")
  updated:SetTextColor(0.65, 0.65, 0.65)
  row.updatedText = updated

  local add = MakeButton(row, "Add", 66, 20)
  add:SetPoint("RIGHT", row, "RIGHT", -150, 0)
  add:SetScript("OnClick", function()
    RLC.DKP:OpenIndividualAction(this.playerName, "ADD")
  end)
  row.addButton = add

  local deduct = MakeButton(row, "Deduct", 72, 20)
  deduct:SetPoint("LEFT", add, "RIGHT", 4, 0)
  deduct:SetScript("OnClick", function()
    RLC.DKP:OpenIndividualAction(this.playerName, "DEDUCT")
  end)
  row.deductButton = deduct

  local set = MakeButton(row, "Set", 58, 20)
  set:SetPoint("LEFT", deduct, "RIGHT", 4, 0)
  set:SetScript("OnClick", function()
    RLC.DKP:OpenIndividualAction(this.playerName, "SET")
  end)
  row.setButton = set
  return row
end

function DKP:BuildPageHeader(page, titleText, subtitleText)
  local title = MakeLabel(page.frame, titleText, "GameFontNormalLarge")
  title:SetPoint("TOP", page.frame, "TOP", 0, -15)
  title:SetTextColor(1, 0.75, 0.25)
  page.title = title

  local subtitle = MakeLabel(page.frame, subtitleText, "GameFontHighlightSmall")
  subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
  subtitle:SetTextColor(0.68, 0.68, 0.68)
  page.subtitle = subtitle
end

function DKP:ApplyRosterPreset(page, preset)
  if not RLC or not RLC.IsAdminRank or not RLC:IsAdminRank() then
    DKPPrint("Access denied: only Tong Bender, Leviathan, or Tracerboy can modify DKP.")
    return
  end
  if page.rosterDropDown and page.rosterDropDown.list then
    page.rosterDropDown.list:Hide()
  end
  local playerName = page.rosterDropDown and page.rosterDropDown.selectedValue
  if not playerName then
    DKPPrint("Select a player from the dropdown first.")
    return
  end
  local operation = preset.amount < 0 and "DEDUCT" or "ADD"
  self:OpenAdjustDialog(playerName, operation, math.abs(preset.amount), preset.reason, preset.label .. " - " .. playerName)
end

function DKP:CreateRosterDropDown(page)
  local parent = page.frame
  local dropdown = CreateFrame("Frame", NextWidgetName("RosterDropDown"), parent)
  dropdown:SetWidth(170)
  dropdown:SetHeight(24)
  dropdown:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  dropdown:SetBackdropColor(0.035, 0.02, 0.015, 0.96)
  dropdown:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)

  local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
  text:SetText("Select player...")
  dropdown.text = text

  local toggle = MakeButton(dropdown, "v", 22, 20)
  toggle:SetPoint("RIGHT", dropdown, "RIGHT", -2, 0)
  dropdown.toggle = toggle

  local list = CreateFrame("Frame", NextWidgetName("RosterDropList"), UIParent)
  list:SetWidth(170)
  list:SetHeight(200)
  list:SetFrameStrata("DIALOG")
  list:SetFrameLevel(200)
  list:EnableMouse(true)
  list:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  list:SetBackdropColor(0.035, 0.02, 0.015, 0.98)
  list:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)
  list:Hide()
  dropdown.list = list

  local scroll = CreateFrame("ScrollFrame", NextWidgetName("RosterDropScroll"), list)
  scroll:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -8)
  scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -22, 6)
  scroll:EnableMouseWheel(true)
  list.scroll = scroll

  local scrollChild = CreateFrame("Frame", nil, scroll)
  scrollChild:SetWidth(130)
  scrollChild:SetHeight(1)
  scroll:SetScrollChild(scrollChild)
  list.scrollChild = scrollChild

  local scrollbar = CreateFrame("Slider", NextWidgetName("RosterDropScrollBar"), list)
  scrollbar:SetWidth(16)
  scrollbar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 2, 0)
  scrollbar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 2, 0)
  scrollbar:SetOrientation("VERTICAL")
  scrollbar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
  local thumb = scrollbar:GetThumbTexture()
  if thumb then thumb:SetWidth(16); thumb:SetHeight(24) end
  scrollbar:SetMinMaxValues(0, 0)
  scrollbar:SetValue(0)
  scrollbar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  scrollbar:SetBackdropColor(0, 0, 0, 0.3)
  scrollbar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
  list.scrollbar = scrollbar

  local updating = false
  scroll:SetScript("OnMouseWheel", function()
    local current = this:GetVerticalScroll()
    local maxScroll = this:GetVerticalScrollRange()
    local newScroll = current - (arg1 * 16)
    if newScroll < 0 then newScroll = 0 end
    if newScroll > maxScroll then newScroll = maxScroll end
    this:SetVerticalScroll(newScroll)
  end)

  scroll:SetScript("OnVerticalScroll", function()
    if updating then return end
    updating = true
    local maxScroll = this:GetVerticalScrollRange()
    if maxScroll > 0 then
      scrollbar:SetValue(this:GetVerticalScroll())
    else
      scrollbar:SetValue(0)
    end
    updating = false
  end)

  scrollbar:SetScript("OnValueChanged", function()
    if updating then return end
    updating = true
    scroll:SetVerticalScroll(this:GetValue())
    updating = false
  end)

  local buttons = {}
  dropdown.buttons = buttons
  local itemHeight = 18

  function dropdown:SetItems(items)
    items = items or {}
    dropdown.items = items
    local needed = math.max(table.getn(buttons), table.getn(items))
    for i = 1, needed do
      local btn = buttons[i]
      if not btn then
        btn = CreateFrame("Button", NextWidgetName("RosterDropItem"), scrollChild)
        btn:SetWidth(130)
        btn:SetHeight(itemHeight)
        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((i - 1) * itemHeight))
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetAllPoints(btn)
        label:SetJustifyH("LEFT")
        btn.label = label
        btn:SetScript("OnEnter", function() this.label:SetTextColor(1, 1, 0.5) end)
        btn:SetScript("OnLeave", function() this.label:SetTextColor(1, 0.82, 0.42) end)
        btn:SetScript("OnClick", function()
          dropdown.selectedValue = this.value
          dropdown.text:SetText(this.text)
          list:Hide()
        end)
        table.insert(buttons, btn)
      end
      local item = items[i]
      if item then
        btn:Show()
        btn.value = item.value
        btn.text = item.text
        btn.label:SetText(item.text)
        btn.label:SetTextColor(1, 0.82, 0.42)
      else
        btn:Hide()
      end
    end
    local totalHeight = table.getn(items) * itemHeight
    scrollChild:SetHeight(math.max(1, totalHeight))
    local viewHeight = scroll:GetHeight()
    local maxScroll = math.max(0, totalHeight - viewHeight)
    scrollbar:SetMinMaxValues(0, maxScroll)
    if maxScroll > 0 then scrollbar:Show() else scrollbar:Hide() end
    local currentScroll = scroll:GetVerticalScroll()
    if currentScroll > maxScroll then
      scroll:SetVerticalScroll(maxScroll)
    elseif maxScroll <= 0 then
      scroll:SetVerticalScroll(0)
    end
    scrollbar:SetValue(scroll:GetVerticalScroll())
  end

  function dropdown:UpdateSelection(items)
    local current = dropdown.selectedValue
    local found = false
    for i = 1, table.getn(items) do
      if items[i].value == current then
        found = true
        break
      end
    end
    if not found and table.getn(items) > 0 then
      dropdown.selectedValue = items[1].value
      dropdown.text:SetText(items[1].text)
    elseif table.getn(items) == 0 then
      dropdown.selectedValue = nil
      dropdown.text:SetText("Select player...")
    end
  end

  toggle:SetScript("OnClick", function()
    if list:IsVisible() then
      list:Hide()
    else
      local x = dropdown:GetLeft()
      local y = dropdown:GetBottom()
      if x and y then
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
      end
      list:Show()
    end
  end)

  dropdown:SetScript("OnHide", function() list:Hide() end)

  return dropdown
end

function DKP:BuildRosterPage(page)
  self:BuildPageHeader(page, "DKP Roster", "Character-bound balances sorted from highest to lowest")

  page.adminControls = {}

  local dropdownLabel = MakeLabel(page.frame, "Quick Add:", "GameFontHighlightSmall")
  dropdownLabel:SetPoint("TOPLEFT", page.frame, "TOPLEFT", 18, -60)
  dropdownLabel:SetTextColor(1, 0.82, 0.42)
  table.insert(page.adminControls, dropdownLabel)

  local dropdown = self:CreateRosterDropDown(page)
  dropdown:SetPoint("TOPLEFT", page.frame, "TOPLEFT", 18, -80)
  page.rosterDropDown = dropdown
  table.insert(page.adminControls, dropdown)

  local presetWidth = 80
  local presetSpacing = 6
  local previous = dropdown
  local presetButtons = {}
  page.presetButtons = presetButtons
  for index = 1, table.getn(self.PRESETS) do
    local preset = self.PRESETS[index]
    local button = MakeButton(page.frame, preset.label, presetWidth, 22)
    if index == 1 then
      button:SetPoint("TOPLEFT", dropdown, "TOPRIGHT", presetSpacing, 0)
    elseif index == 6 then
      previous = dropdown
      button:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -8)
    else
      button:SetPoint("TOPLEFT", previous, "TOPRIGHT", presetSpacing, 0)
    end
    button.preset = preset
    button:SetScript("OnClick", function() RLC.DKP:ApplyRosterPreset(this.page, this.preset) end)
    button.page = page
    table.insert(presetButtons, button)
    table.insert(page.adminControls, button)
    previous = button
  end

  local refresh = MakeButton(page.frame, "Refresh", 78, 22)
  refresh:SetPoint("LEFT", previous, "RIGHT", 20, 0)
  refresh:SetScript("OnClick", function()
    RLC.DKP:RequestGuildRoster(true)
    RLC.DKP:RefreshPage(this.page)
  end)
  refresh.page = page

  local sync = MakeButton(page.frame, "Sync", 72, 22)
  sync:SetPoint("LEFT", refresh, "RIGHT", 7, 0)
  sync:SetScript("OnClick", function() RLC.DKP:RequestSync() end)

  local export = MakeButton(page.frame, "Export", 78, 22)
  export:SetPoint("LEFT", sync, "RIGHT", 7, 0)
  export:SetScript("OnClick", function() RLC.DKP:ShowExport("roster") end)

  local list = CreateFrame("Frame", nil, page.frame)
  list:SetPoint("TOPLEFT", page.frame, "TOPLEFT", 18, -144)
  list:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOMRIGHT", -18, 18)
  SetDarkBackdrop(list, 0.64)
  page.listFrame = list
  page.visibleRows = 18
  page.offset = 0
  page.rows = {}

  local headers = {
    { text = "#", x = 7, width = 32, justify = "RIGHT" },
    { text = "Character", x = 50, width = 185, justify = "LEFT" },
    { text = "Class", x = 240, width = 105, justify = "LEFT" },
    { text = "DKP", x = 355, width = 95, justify = "RIGHT" },
    { text = "Last Change", x = 468, width = 215, justify = "LEFT" },
    { text = "Manual Controls", x = -210, width = 200, justify = "CENTER", right = true },
  }
  for i = 1, table.getn(headers) do
    local header = MakeLabel(list, headers[i].text, "GameFontNormalSmall")
    if headers[i].right then
      header:SetPoint("TOPRIGHT", list, "TOPRIGHT", headers[i].x, -8)
    else
      header:SetPoint("TOPLEFT", list, "TOPLEFT", headers[i].x, -8)
    end
    header:SetWidth(headers[i].width)
    header:SetJustifyH(headers[i].justify)
    header:SetTextColor(1, 0.74, 0.30)
  end

  local rowsContainer = CreateFrame("Frame", nil, list)
  rowsContainer:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -28)
  rowsContainer:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -8, 8)
  rowsContainer:EnableMouseWheel(true)
  rowsContainer.page = page
  rowsContainer:SetScript("OnMouseWheel", function()
    local target = this.page
    local direction = arg1 or 0
    target.offset = math.max(0, (target.offset or 0) - (direction * 3))
    RLC.DKP:RefreshPage(target)
  end)
  page.rowsContainer = rowsContainer

  for index = 1, page.visibleRows do
    local row = self:CreateRosterRow(rowsContainer)
    row:SetPoint("TOPLEFT", rowsContainer, "TOPLEFT", 0, -((index - 1) * 26))
    table.insert(page.rows, row)
  end

  local empty = MakeLabel(list, "", "GameFontHighlight")
  empty:SetPoint("CENTER", list, "CENTER", 0, 0)
  empty:SetTextColor(0.72, 0.72, 0.72)
  page.emptyText = empty
end

function DKP:RefreshRosterPage(page)
  local members = self:GetRosterMembers()
  local guildName, guildKey = ActiveGuildContext()
  local maxOffset = math.max(0, table.getn(members) - page.visibleRows)
  if page.offset > maxOffset then page.offset = maxOffset end

  if table.getn(members) == 0 then
    if not guildName then
      page.emptyText:SetText("You are not currently in a guild.")
    elseif self.rosterReadyGuildKey ~= guildKey then
      page.emptyText:SetText("Loading the " .. guildName .. " roster...")
    else
      page.emptyText:SetText("No characters were returned for " .. guildName .. ".")
    end
    page.emptyText:Show()
  else
    page.emptyText:Hide()
  end

  local isAdmin = RLC and RLC.IsAdminRank and RLC:IsAdminRank()

  -- Update the quick-add dropdown with every roster member, sorted alphabetically.
  if page.rosterDropDown then
    local dropItems = {}
    for i = 1, table.getn(members) do
      table.insert(dropItems, { text = members[i].name, value = members[i].name })
    end
    table.sort(dropItems, function(a, b) return Lower(a.text) < Lower(b.text) end)
    page.rosterDropDown:SetItems(dropItems)
    page.rosterDropDown:UpdateSelection(dropItems)
  end

  -- Show/hide the admin-only quick-add controls and row-level buttons.
  local controls = page.adminControls or {}
  for i = 1, table.getn(controls) do
    local control = controls[i]
    if control and control.Show then
      if isAdmin then control:Show() else control:Hide() end
    end
  end

  for rowIndex = 1, page.visibleRows do
    local row = page.rows[rowIndex]
    local memberIndex = page.offset + rowIndex
    local member = members[memberIndex]
    if member then
      row.rankText:SetText(tostring(memberIndex))
      local classToken = string.upper(tostring(member.class or ""))
      row.nameText:SetText(ClassColoredName(member.name, classToken))
      row.classText:SetText(member.class or "")
      row.balanceText:SetText(tostring(member.balance or 0))
      local record = member.balanceRecord
      if record and (record.updatedAt or 0) > 0 then
        row.updatedText:SetText(date("%m/%d %H:%M", record.updatedAt) .. " by " .. tostring(record.updatedBy or "Unknown"))
      else
        row.updatedText:SetText("No transactions")
      end
      row.addButton.playerName = member.name
      row.deductButton.playerName = member.name
      row.setButton.playerName = member.name
      if isAdmin then
        row.addButton:Show()
        row.deductButton:Show()
        row.setButton:Show()
      else
        row.addButton:Hide()
        row.deductButton:Hide()
        row.setButton:Hide()
      end
      if math.mod(memberIndex, 2) == 0 then
        row.background:SetVertexColor(0.11, 0.045, 0.02, 0.46)
      else
        row.background:SetVertexColor(0.20, 0.085, 0.03, 0.56)
      end
      row:Show()
    else
      row:Hide()
    end
  end
  page.subtitle:SetText((guildName or "No active guild") .. " only  |  Character-bound balances sorted highest to lowest  |  " .. tostring(table.getn(members)) .. " characters")
end

function DKP:CreateRaidRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(25)
  row:SetPoint("LEFT", parent, "LEFT", 0, 0)
  row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

  local background = row:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(row)
  background:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  background:SetVertexColor(0.16, 0.075, 0.035, 0.58)
  row.background = background

  local group = MakeLabel(row, "", "GameFontHighlightSmall")
  group:SetPoint("LEFT", row, "LEFT", 8, 0)
  group:SetWidth(48)
  group:SetJustifyH("CENTER")
  row.groupText = group

  local name = MakeLabel(row, "", "GameFontHighlight")
  name:SetPoint("LEFT", row, "LEFT", 64, 0)
  name:SetWidth(220)
  name:SetJustifyH("LEFT")
  row.nameText = name

  local status = MakeLabel(row, "", "GameFontHighlightSmall")
  status:SetPoint("LEFT", row, "LEFT", 290, 0)
  status:SetWidth(170)
  status:SetJustifyH("LEFT")
  row.statusText = status

  local balance = MakeLabel(row, "", "GameFontNormal")
  balance:SetPoint("LEFT", row, "LEFT", 470, 0)
  balance:SetWidth(90)
  balance:SetJustifyH("RIGHT")
  balance:SetTextColor(1, 0.82, 0.28)
  row.balanceText = balance

  local add = MakeButton(row, "Add", 66, 20)
  add:SetPoint("RIGHT", row, "RIGHT", -150, 0)
  add:SetScript("OnClick", function() RLC.DKP:OpenIndividualAction(this.playerName, "ADD") end)
  row.addButton = add

  local deduct = MakeButton(row, "Deduct", 72, 20)
  deduct:SetPoint("LEFT", add, "RIGHT", 4, 0)
  deduct:SetScript("OnClick", function() RLC.DKP:OpenIndividualAction(this.playerName, "DEDUCT") end)
  row.deductButton = deduct

  local set = MakeButton(row, "Set", 58, 20)
  set:SetPoint("LEFT", deduct, "RIGHT", 4, 0)
  set:SetScript("OnClick", function() RLC.DKP:OpenIndividualAction(this.playerName, "SET") end)
  row.setButton = set
  return row
end

function DKP:BuildRaidPage(page)
  self:BuildPageHeader(page, "Active Raid DKP", "Current raid members with individual and raid-wide controls")
  page.adminButtons = {}

  local previous
  for index = 1, table.getn(self.PRESETS) do
    local preset = self.PRESETS[index]
    local button = MakeButton(page.frame, preset.label, 92, 22)
    if index == 1 then
      button:SetPoint("TOPLEFT", page.frame, "TOPLEFT", 18, -58)
    elseif index == 6 then
      button:SetPoint("TOPLEFT", page.frame, "TOPLEFT", 18, -85)
    else
      button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
    end
    button.preset = preset
    button:SetScript("OnClick", function() RLC.DKP:OpenRaidPreset(this.preset) end)
    table.insert(page.adminButtons, button)
    previous = button
  end

  local addAll = MakeButton(page.frame, "Add All", 82, 22)
  addAll:SetPoint("TOPRIGHT", page.frame, "TOPRIGHT", -192, -58)
  addAll:SetScript("OnClick", function()
    RLC.DKP:OpenAdjustDialog(RLC.DKP:GetRaidNames(), "ADD", nil, "Raid-wide adjustment", "Add DKP - Entire Raid")
  end)
  table.insert(page.adminButtons, addAll)

  local deductAll = MakeButton(page.frame, "Deduct All", 96, 22)
  deductAll:SetPoint("LEFT", addAll, "RIGHT", 6, 0)
  deductAll:SetScript("OnClick", function()
    RLC.DKP:OpenAdjustDialog(RLC.DKP:GetRaidNames(), "DEDUCT", nil, "Raid-wide adjustment", "Deduct DKP - Entire Raid")
  end)
  table.insert(page.adminButtons, deductAll)

  local setAll = MakeButton(page.frame, "Set All", 82, 22)
  setAll:SetPoint("TOPRIGHT", page.frame, "TOPRIGHT", -192, -85)
  setAll:SetScript("OnClick", function()
    RLC.DKP:OpenAdjustDialog(RLC.DKP:GetRaidNames(), "SET", nil, "Raid-wide balance correction", "Set DKP - Entire Raid")
  end)
  table.insert(page.adminButtons, setAll)

  local compact = MakeButton(page.frame, "Compact", 96, 22)
  compact:SetPoint("LEFT", setAll, "RIGHT", 6, 0)
  compact:SetScript("OnClick", function() RLC.DKP:ToggleCompact() end)

  local list = CreateFrame("Frame", nil, page.frame)
  list:SetPoint("TOPLEFT", page.frame, "TOPLEFT", 18, -126)
  list:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOMRIGHT", -18, 18)
  SetDarkBackdrop(list, 0.64)
  page.listFrame = list
  page.visibleRows = 18
  page.offset = 0
  page.rows = {}

  local headers = {
    { text = "Group", x = 8, width = 48, justify = "CENTER" },
    { text = "Character", x = 64, width = 220, justify = "LEFT" },
    { text = "Status", x = 290, width = 170, justify = "LEFT" },
    { text = "DKP", x = 470, width = 90, justify = "RIGHT" },
  }
  for i = 1, table.getn(headers) do
    local header = MakeLabel(list, headers[i].text, "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", list, "TOPLEFT", headers[i].x, -8)
    header:SetWidth(headers[i].width)
    header:SetJustifyH(headers[i].justify)
    header:SetTextColor(1, 0.74, 0.30)
  end
  local controlsHeader = MakeLabel(list, "Manual Controls", "GameFontNormalSmall")
  controlsHeader:SetPoint("TOPRIGHT", list, "TOPRIGHT", -10, -8)
  controlsHeader:SetWidth(210)
  controlsHeader:SetJustifyH("CENTER")
  controlsHeader:SetTextColor(1, 0.74, 0.30)

  local rowsContainer = CreateFrame("Frame", nil, list)
  rowsContainer:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -28)
  rowsContainer:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -8, 8)
  rowsContainer:EnableMouseWheel(true)
  rowsContainer.page = page
  rowsContainer:SetScript("OnMouseWheel", function()
    local target = this.page
    target.offset = math.max(0, (target.offset or 0) - ((arg1 or 0) * 3))
    RLC.DKP:RefreshPage(target)
  end)
  page.rowsContainer = rowsContainer

  for index = 1, page.visibleRows do
    local row = self:CreateRaidRow(rowsContainer)
    row:SetPoint("TOPLEFT", rowsContainer, "TOPLEFT", 0, -((index - 1) * 26))
    table.insert(page.rows, row)
  end

  local empty = MakeLabel(list, "No active raid. Join a raid to populate this list.", "GameFontHighlight")
  empty:SetPoint("CENTER", list, "CENTER", 0, 0)
  empty:SetTextColor(0.7, 0.7, 0.7)
  page.emptyText = empty
end

function DKP:RefreshRaidPage(page)
  local members = self:GetRaidMembers()
  local maxOffset = math.max(0, table.getn(members) - page.visibleRows)
  if page.offset > maxOffset then page.offset = maxOffset end

  if table.getn(members) == 0 then
    page.emptyText:Show()
  else
    page.emptyText:Hide()
  end

  local isAdmin = RLC and RLC.IsAdminRank and RLC:IsAdminRank()
  for i = 1, table.getn(page.adminButtons or {}) do
    local button = page.adminButtons[i]
    if isAdmin then button:Show() else button:Hide() end
  end

  for rowIndex = 1, page.visibleRows do
    local row = page.rows[rowIndex]
    local memberIndex = page.offset + rowIndex
    local member = members[memberIndex]
    if member then
      row.groupText:SetText(tostring(member.subgroup))
      row.nameText:SetText(ClassColoredName(member.name, member.classToken))
      local status = member.zone or ""
      if not member.online then
        status = "Offline"
      elseif member.dead then
        status = status ~= "" and (status .. " - Dead") or "Dead"
      end
      row.statusText:SetText(status)
      row.balanceText:SetText(tostring(member.balance or 0))
      row.addButton.playerName = member.name
      row.deductButton.playerName = member.name
      row.setButton.playerName = member.name
      if isAdmin then
        row.addButton:Show()
        row.deductButton:Show()
        row.setButton:Show()
      else
        row.addButton:Hide()
        row.deductButton:Hide()
        row.setButton:Hide()
      end
      if math.mod(memberIndex, 2) == 0 then
        row.background:SetVertexColor(0.11, 0.045, 0.02, 0.46)
      else
        row.background:SetVertexColor(0.20, 0.085, 0.03, 0.56)
      end
      row:Show()
    else
      row:Hide()
    end
  end
  page.subtitle:SetText("Current raid members with individual and raid-wide controls  |  " .. tostring(table.getn(members)) .. "/40")
end

function DKP:CreateHistoryRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(26)
  row:SetPoint("LEFT", parent, "LEFT", 0, 0)
  row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

  local background = row:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(row)
  background:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  background:SetVertexColor(0.16, 0.075, 0.035, 0.58)
  row.background = background

  local whenText = MakeLabel(row, "", "GameFontHighlightSmall")
  whenText:SetPoint("LEFT", row, "LEFT", 8, 0)
  whenText:SetWidth(105)
  whenText:SetJustifyH("LEFT")
  row.whenText = whenText

  local nameText = MakeLabel(row, "", "GameFontHighlight")
  nameText:SetPoint("LEFT", row, "LEFT", 120, 0)
  nameText:SetWidth(150)
  nameText:SetJustifyH("LEFT")
  row.nameText = nameText

  local amountText = MakeLabel(row, "", "GameFontNormal")
  amountText:SetPoint("LEFT", row, "LEFT", 275, 0)
  amountText:SetWidth(75)
  amountText:SetJustifyH("RIGHT")
  row.amountText = amountText

  local balanceText = MakeLabel(row, "", "GameFontHighlightSmall")
  balanceText:SetPoint("LEFT", row, "LEFT", 365, 0)
  balanceText:SetWidth(105)
  balanceText:SetJustifyH("CENTER")
  row.balanceText = balanceText

  local reasonText = MakeLabel(row, "", "GameFontHighlightSmall")
  reasonText:SetPoint("LEFT", row, "LEFT", 485, 0)
  reasonText:SetPoint("RIGHT", row, "RIGHT", -155, 0)
  reasonText:SetJustifyH("LEFT")
  row.reasonText = reasonText

  local actorText = MakeLabel(row, "", "GameFontHighlightSmall")
  actorText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
  actorText:SetWidth(135)
  actorText:SetJustifyH("RIGHT")
  actorText:SetTextColor(0.68, 0.68, 0.68)
  row.actorText = actorText
  return row
end

function DKP:BuildHistoryPage(page)
  self:BuildPageHeader(page, "DKP History", "Permanent transaction ledger; corrections create new entries")

  local export = MakeButton(page.frame, "Export Log", 100, 22)
  export:SetPoint("TOPLEFT", page.frame, "TOPLEFT", 18, -58)
  export:SetScript("OnClick", function() RLC.DKP:ShowExport("history") end)

  local sync = MakeButton(page.frame, "Sync", 72, 22)
  sync:SetPoint("LEFT", export, "RIGHT", 7, 0)
  sync:SetScript("OnClick", function() RLC.DKP:RequestSync() end)

  local list = CreateFrame("Frame", nil, page.frame)
  list:SetPoint("TOPLEFT", page.frame, "TOPLEFT", 18, -96)
  list:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOMRIGHT", -18, 18)
  SetDarkBackdrop(list, 0.64)
  page.listFrame = list
  page.visibleRows = 20
  page.offset = 0
  page.rows = {}

  local headers = {
    { text = "Time", x = 8, width = 105, justify = "LEFT" },
    { text = "Character", x = 120, width = 150, justify = "LEFT" },
    { text = "Change", x = 275, width = 75, justify = "RIGHT" },
    { text = "Balance", x = 365, width = 105, justify = "CENTER" },
    { text = "Reason", x = 485, width = 260, justify = "LEFT" },
  }
  for i = 1, table.getn(headers) do
    local header = MakeLabel(list, headers[i].text, "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", list, "TOPLEFT", headers[i].x, -8)
    header:SetWidth(headers[i].width)
    header:SetJustifyH(headers[i].justify)
    header:SetTextColor(1, 0.74, 0.30)
  end
  local actorHeader = MakeLabel(list, "Changed By", "GameFontNormalSmall")
  actorHeader:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -8)
  actorHeader:SetWidth(135)
  actorHeader:SetJustifyH("RIGHT")
  actorHeader:SetTextColor(1, 0.74, 0.30)

  local rowsContainer = CreateFrame("Frame", nil, list)
  rowsContainer:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -28)
  rowsContainer:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -8, 8)
  rowsContainer:EnableMouseWheel(true)
  rowsContainer.page = page
  rowsContainer:SetScript("OnMouseWheel", function()
    local target = this.page
    target.offset = math.max(0, (target.offset or 0) - ((arg1 or 0) * 3))
    RLC.DKP:RefreshPage(target)
  end)
  page.rowsContainer = rowsContainer

  for index = 1, page.visibleRows do
    local row = self:CreateHistoryRow(rowsContainer)
    row:SetPoint("TOPLEFT", rowsContainer, "TOPLEFT", 0, -((index - 1) * 27))
    table.insert(page.rows, row)
  end

  local empty = MakeLabel(list, "No DKP transactions have been recorded yet.", "GameFontHighlight")
  empty:SetPoint("CENTER", list, "CENTER", 0, 0)
  empty:SetTextColor(0.7, 0.7, 0.7)
  page.emptyText = empty
end

function DKP:RefreshHistoryPage(page)
  local db = self:EnsureDB()
  local count = table.getn(db.transactions)
  local maxOffset = math.max(0, count - page.visibleRows)
  if page.offset > maxOffset then page.offset = maxOffset end
  if count == 0 then
    page.emptyText:Show()
  else
    page.emptyText:Hide()
  end

  for rowIndex = 1, page.visibleRows do
    local row = page.rows[rowIndex]
    local transactionIndex = count - page.offset - rowIndex + 1
    local transaction = db.transactions[transactionIndex]
    if transaction then
      row.whenText:SetText(date("%m/%d %H:%M", transaction.timestamp or 0))
      row.nameText:SetText(transaction.name or "")
      if transaction.operation == "SET" then
        row.amountText:SetText("|cFFFFD700SET|r")
      else
        local amount = tonumber(transaction.after or 0) - tonumber(transaction.before or 0)
        if amount >= 0 then
          row.amountText:SetText("|cFF55FF55+" .. tostring(amount) .. "|r")
        else
          row.amountText:SetText("|cFFFF6666" .. tostring(amount) .. "|r")
        end
      end
      row.balanceText:SetText(tostring(transaction.before or 0) .. " -> " .. tostring(transaction.after or 0))
      row.reasonText:SetText(transaction.reason or "")
      row.actorText:SetText(transaction.actor or "Unknown")
      if math.mod(transactionIndex, 2) == 0 then
        row.background:SetVertexColor(0.11, 0.045, 0.02, 0.46)
      else
        row.background:SetVertexColor(0.20, 0.085, 0.03, 0.56)
      end
      row:Show()
    else
      row:Hide()
    end
  end
  page.subtitle:SetText("Permanent transaction ledger; corrections create new entries  |  " .. tostring(count) .. " transactions")
end

function DKP:BuildPage(parent, mode)
  if not parent then return nil end
  if parent._rlcDKPPage then return parent._rlcDKPPage end

  local page = {
    frame = parent,
    mode = mode or "roster",
  }
  parent._rlcDKPPage = page
  table.insert(self.pages, page)

  if page.mode == "raid" then
    self:BuildRaidPage(page)
  elseif page.mode == "history" then
    self:BuildHistoryPage(page)
  else
    self:BuildRosterPage(page)
  end
  return page
end

function DKP:RefreshPage(page)
  if not page then return end
  if page.mode == "raid" then
    self:RefreshRaidPage(page)
  elseif page.mode == "history" then
    self:RefreshHistoryPage(page)
  else
    self:RefreshRosterPage(page)
  end
end

function DKP:RefreshAll()
  for i = 1, table.getn(self.pages or {}) do
    local page = self.pages[i]
    if page and page.frame then
      self:RefreshPage(page)
    end
  end
  self:RefreshCompact()
end

function DKP:SaveFramePosition(frame, settings)
  if not frame or not settings then return end
  local point, relativeTo, relativePoint, x, y = frame:GetPoint()
  settings.point = point or "CENTER"
  settings.relativePoint = relativePoint or "CENTER"
  settings.x = x or 0
  settings.y = y or 0
end

function DKP:RestoreFramePosition(frame, settings)
  if not frame or not settings then return end
  frame:ClearAllPoints()
  frame:SetPoint(settings.point or "CENTER", UIParent, settings.relativePoint or "CENTER", settings.x or 0, settings.y or 0)
end

function DKP:UpdateCompactGeometry(frame)
  if not frame or not frame.scrollChild then return end
  local contentWidth = math.max(150, (frame:GetWidth() or 220) - 24)
  frame.scrollChild:SetWidth(contentWidth)

  local scroll = frame.scrollFrame
  if scroll and scroll.GetVerticalScroll and scroll.GetVerticalScrollRange then
    local current = scroll:GetVerticalScroll() or 0
    local maximum = scroll:GetVerticalScrollRange() or 0
    if current > maximum then scroll:SetVerticalScroll(maximum) end
  end
end

function DKP:SaveCompactSize(frame)
  if not frame then return end
  self:EnsureDB()
  local settings = RLC_DB.dkpUI.compact
  settings.width = Clamp(RoundInteger(frame:GetWidth() or 220), 190, 420)
  settings.height = Clamp(RoundInteger(frame:GetHeight() or 82), 74, 650)
  settings.userSized = true
  self:SaveFramePosition(frame, settings)
end

function DKP:CreateCompactFrame()
  if self.compactFrame then return self.compactFrame end
  self:EnsureDB()
  local settings = RLC_DB.dkpUI.compact

  local frame = CreateFrame("Frame", "RLC_DKP_CompactFrame", UIParent)
  frame:SetWidth(Clamp(settings.width or 220, 190, 420))
  frame:SetHeight(Clamp(settings.height or 82, 74, 650))
  frame:SetFrameStrata("HIGH")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  if frame.SetResizable then frame:SetResizable(true) end
  if frame.SetMinResize then frame:SetMinResize(190, 74) end
  if frame.SetMaxResize then frame:SetMaxResize(420, 650) end
  frame:RegisterForDrag("LeftButton")
  frame:SetClampedToScreen(true)
  SetDarkBackdrop(frame, 0.90)
  frame:SetScale(Clamp(settings.scale or 0.90, 0.55, 1.50))
  self:RestoreFramePosition(frame, settings)
  frame:SetScript("OnDragStart", function()
    if not RLC_DB.dkpUI.compact.locked then this:StartMoving() end
  end)
  frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    RLC.DKP:SaveFramePosition(this, RLC_DB.dkpUI.compact)
  end)
  frame:SetScript("OnHide", function()
    this:StopMovingOrSizing()
    this._rlcCompactSizing = nil
    if RLC_DB and RLC_DB.dkpUI and RLC_DB.dkpUI.compact then
      RLC_DB.dkpUI.compact.visible = false
    end
  end)

  local header = CreateFrame("Frame", nil, frame)
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
  header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
  header:SetHeight(25)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function()
    if not RLC_DB.dkpUI.compact.locked then frame:StartMoving() end
  end)
  header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    RLC.DKP:SaveFramePosition(frame, RLC_DB.dkpUI.compact)
  end)
  frame.header = header

  local title = MakeLabel(header, "Raid DKP", "GameFontNormal")
  title:SetPoint("LEFT", header, "LEFT", 7, 0)
  title:SetTextColor(1, 0.72, 0.25)
  frame.title = title

  local close = MakeButton(header, "X", 24, 20)
  close:SetPoint("RIGHT", header, "RIGHT", -2, 0)
  close:SetScript("OnClick", function() RLC.DKP:SetCompactVisible(false) end)

  local lock = MakeButton(header, settings.locked and "Unlock" or "Lock", 50, 20)
  lock:SetPoint("RIGHT", close, "LEFT", -3, 0)
  lock:SetScript("OnClick", function() RLC.DKP:ToggleCompactLock() end)
  frame.lockButton = lock

  local scroll = CreateFrame("ScrollFrame", NextWidgetName("CompactScroll"), frame)
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -31)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 18)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function()
    local direction = tonumber(arg1) or 0
    local current = this:GetVerticalScroll() or 0
    local maximum = this.GetVerticalScrollRange and (this:GetVerticalScrollRange() or 0) or 0
    this:SetVerticalScroll(Clamp(current - (direction * 36), 0, maximum))
  end)
  frame.scrollFrame = scroll

  local scrollChild = CreateFrame("Frame", nil, scroll)
  scrollChild:SetWidth(math.max(150, (frame:GetWidth() or 220) - 24))
  scrollChild:SetHeight(18)
  scroll:SetScrollChild(scrollChild)
  frame.scrollChild = scrollChild

  frame.entries = {}
  for index = 1, 40 do
    local entry = CreateFrame("Frame", nil, scrollChild)
    entry:SetHeight(18)
    entry:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((index - 1) * 18))
    entry:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -((index - 1) * 18))

    local background = entry:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(entry)
    background:SetTexture(1, 1, 1, math.mod(index, 2) == 0 and 0.035 or 0)

    local nameText = MakeLabel(entry, "", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", entry, "LEFT", 2, 0)
    nameText:SetPoint("RIGHT", entry, "RIGHT", -54, 0)
    nameText:SetJustifyH("LEFT")
    entry.nameText = nameText

    local balanceText = MakeLabel(entry, "", "GameFontHighlightSmall")
    balanceText:SetWidth(48)
    balanceText:SetPoint("RIGHT", entry, "RIGHT", -2, 0)
    balanceText:SetJustifyH("RIGHT")
    balanceText:SetTextColor(1, 0.82, 0.29)
    entry.balanceText = balanceText
    frame.entries[index] = entry
  end

  local resizeGrip = CreateFrame("Button", NextWidgetName("ResizeGrip"), frame)
  resizeGrip:SetWidth(18)
  resizeGrip:SetHeight(18)
  resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
  resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  resizeGrip:SetAlpha(settings.locked and 0.30 or 1)
  resizeGrip:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" and not RLC_DB.dkpUI.compact.locked and frame.StartSizing then
      frame._rlcCompactSizing = true
      frame:StartSizing("BOTTOMRIGHT")
    end
  end)
  resizeGrip:SetScript("OnMouseUp", function()
    if not frame._rlcCompactSizing then return end
    frame._rlcCompactSizing = nil
    frame:StopMovingOrSizing()
    RLC.DKP:SaveCompactSize(frame)
    RLC.DKP:UpdateCompactGeometry(frame)
  end)
  frame.resizeGrip = resizeGrip

  self.compactFrame = frame
  frame:SetScript("OnSizeChanged", function()
    if RLC and RLC.DKP then RLC.DKP:UpdateCompactGeometry(this) end
  end)
  frame:Hide()
  return frame
end

function DKP:RefreshCompact()
  if not self.compactFrame or not self.compactFrame:IsShown() then return end
  local frame = self.compactFrame
  local members = self:GetRaidMembers()
  local count = table.getn(members)
  local displayCount = math.max(1, count)
  local settings = RLC_DB.dkpUI.compact

  if not settings.userSized then
    local naturalRows = math.min(displayCount, 14)
    local naturalHeight = 46 + (naturalRows * 18)
    naturalHeight = Clamp(naturalHeight, 82, 298)
    frame:SetHeight(naturalHeight)
    settings.height = naturalHeight
  end

  frame.title:SetText("Raid DKP  |cFFFFFFFF" .. tostring(count) .. "/40|r")
  for index = 1, 40 do
    local entry = frame.entries[index]
    local member = members[index]
    if member then
      entry.nameText:SetText(ClassColoredName(member.name, member.classToken))
      entry.balanceText:SetText(tostring(member.balance or 0))
      entry:Show()
    else
      entry:Hide()
    end
  end

  if count == 0 then
    local entry = frame.entries[1]
    entry.nameText:SetText("|cFFAAAAAANo active raid|r")
    entry.balanceText:SetText("")
    entry:Show()
  end
  frame.scrollChild:SetHeight(displayCount * 18)
  self:UpdateCompactGeometry(frame)
end

function DKP:SetCompactVisible(visible)
  self:EnsureDB()
  if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then
    visible = false
  end
  local frame = self:CreateCompactFrame()
  RLC_DB.dkpUI.compact.visible = visible and true or false
  if visible then
    frame:Show()
    frame:Raise()
    self:RefreshCompact()
  else
    frame:Hide()
  end
end

function DKP:ToggleCompact()
  if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then
    DKPPrint("Access denied: DKP is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.")
    return
  end
  local frame = self:CreateCompactFrame()
  self:SetCompactVisible(not frame:IsShown())
end

function DKP:ChangeCompactScale(delta)
  self:EnsureDB()
  local settings = RLC_DB.dkpUI.compact
  settings.scale = Clamp((tonumber(settings.scale) or 0.90) + delta, 0.55, 1.50)
  local frame = self:CreateCompactFrame()
  frame:SetScale(settings.scale)
  DKPPrint("Compact scale: " .. tostring(math.floor(settings.scale * 100 + 0.5)) .. "%")
end

function DKP:ToggleCompactLock()
  self:EnsureDB()
  local settings = RLC_DB.dkpUI.compact
  settings.locked = not settings.locked
  local frame = self:CreateCompactFrame()
  frame.lockButton:SetText(settings.locked and "Unlock" or "Lock")
  if frame.resizeGrip then frame.resizeGrip:SetAlpha(settings.locked and 0.30 or 1) end
  DKPPrint("Compact frame " .. (settings.locked and "locked." or "unlocked."))
end

function DKP:CreateStandaloneWindow()
  if self.standalone then return self.standalone end
  self:EnsureDB()
  local settings = RLC_DB.dkpUI.window

  local frame = CreateFrame("Frame", "RLC_DKP_StandaloneFrame", UIParent)
  frame:SetWidth(1060)
  frame:SetHeight(730)
  frame:SetFrameStrata("HIGH")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetClampedToScreen(true)
  frame:SetScale(Clamp(settings.scale or 1, 0.70, 1.25))
  SetDarkBackdrop(frame, 0.985)
  self:RestoreFramePosition(frame, settings)
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    RLC.DKP:SaveFramePosition(this, RLC_DB.dkpUI.window)
  end)
  frame:SetScript("OnHide", function()
    if RLC.DKP.adjustDialog then RLC.DKP.adjustDialog:Hide() end
  end)

  local title = MakeLabel(frame, "Red Lobster Cult DKP", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -15)
  title:SetTextColor(1, 0.72, 0.25)

  local close = MakeButton(frame, "X", 28, 22)
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
  close:SetScript("OnClick", function() RLC.DKP.standalone:Hide() end)

  local compact = MakeButton(frame, "Compact Raid List", 130, 22)
  compact:SetPoint("RIGHT", close, "LEFT", -8, 0)
  compact:SetScript("OnClick", function() RLC.DKP:ToggleCompact() end)

  local tabNames = {
    { key = "roster", text = "Roster" },
    { key = "raid", text = "Raid" },
    { key = "history", text = "History" },
  }
  frame.tabs = {}
  local previousTab
  for index = 1, table.getn(tabNames) do
    local tabInfo = tabNames[index]
    local tab = MakeButton(frame, tabInfo.text, 92, 24)
    if index == 1 then
      tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -48)
    else
      tab:SetPoint("LEFT", previousTab, "RIGHT", 6, 0)
    end
    tab.tabKey = tabInfo.key
    tab:SetScript("OnClick", function() RLC.DKP:ShowStandaloneTab(this.tabKey) end)
    frame.tabs[tabInfo.key] = tab
    previousTab = tab
  end

  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -80)
  content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
  frame.content = content
  frame.pages = {}

  for _, mode in ipairs({"roster", "raid", "history"}) do
    local pageFrame = CreateFrame("Frame", nil, content)
    pageFrame:SetAllPoints(content)
    pageFrame:Hide()
    frame.pages[mode] = pageFrame
    self:BuildPage(pageFrame, mode)
  end

  self.standalone = frame
  frame:Hide()
  self:ShowStandaloneTab(settings.tab or "roster")
  return frame
end

function DKP:ShowStandaloneTab(tabKey)
  if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then
    return
  end
  local frame = self.standalone or self:CreateStandaloneWindow()
  tabKey = frame.pages[tabKey] and tabKey or "roster"
  RLC_DB.dkpUI.window.tab = tabKey
  for key, pageFrame in pairs(frame.pages) do
    if key == tabKey then
      pageFrame:Show()
      self:RefreshPage(pageFrame._rlcDKPPage)
    else
      pageFrame:Hide()
    end
  end
  for key, tab in pairs(frame.tabs) do
    local fontString = tab.GetFontString and tab:GetFontString()
    if fontString then
      if key == tabKey then
        fontString:SetTextColor(1, 0.82, 0.25)
      else
        fontString:SetTextColor(0.85, 0.72, 0.58)
      end
    end
  end
end

function DKP:ToggleStandalone(tabKey)
  if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then
    DKPPrint("Access denied: DKP is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.")
    return
  end
  local frame = self:CreateStandaloneWindow()
  if frame:IsShown() and not tabKey then
    frame:Hide()
    return
  end
  if tabKey then self:ShowStandaloneTab(tabKey) end
  frame:Show()
  frame:Raise()
  self:RefreshAll()
end

function DKP:HandleSlashCommand(message)
  if not RLC or not RLC.HasLeafAccess or not RLC:HasLeafAccess() then
    DKPPrint("Access denied: DKP is restricted to guild ranks Krill, Blue Lobster, Crab, Lobster Knight, Tong Bender, or Leviathan.")
    return
  end

  local text = Lower(Trim(message))
  if text == "" then
    self:ToggleStandalone()
  elseif text == "compact" then
    self:ToggleCompact()
  elseif text == "roster" or text == "raid" or text == "history" then
    self:ToggleStandalone(text)
  elseif text == "sync" then
    self:RequestSync()
  elseif text == "help" then
    DKPPrint("/dkp - toggle the full DKP window")
    DKPPrint("/dkp roster | raid | history - open a specific section")
    DKPPrint("/dkp compact - toggle the movable compact raid list")
    DKPPrint("/dkp sync - request balances from an officer")
  else
    DKPPrint("Unknown command. Use /dkp help.")
  end
end

function DKP:Initialize()
  self:EnsureDB()
  self:RequestGuildRoster(false)
  if not self.messageFrame then
    local queueFrame = CreateFrame("Frame")
    queueFrame:Hide()
    queueFrame:SetScript("OnUpdate", function()
      RLC.DKP.messageElapsed = (RLC.DKP.messageElapsed or 0) + (arg1 or 0)
      if RLC.DKP.messageElapsed < 0.12 then return end
      RLC.DKP.messageElapsed = 0
      local nextMessage = table.remove(RLC.DKP.messageQueue, 1)
      if nextMessage then
        RLC.DKP:SendMessageNow(nextMessage)
      end
      if table.getn(RLC.DKP.messageQueue) == 0 then
        this:Hide()
      end
    end)
    self.messageFrame = queueFrame
  end
end

SLASH_RLCDKP1 = "/dkp"
SlashCmdList["RLCDKP"] = function(message)
  RLC.DKP:HandleSlashCommand(message)
end

local eventFrame = CreateFrame("Frame", "RLC_DKP_EventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
eventFrame:SetScript("OnEvent", function()
  local currentEvent = event
  if currentEvent == "ADDON_LOADED" and arg1 == "RedLobsterCult" then
    RLC.DKP:Initialize()
  elseif currentEvent == "PLAYER_LOGIN" then
    RLC.DKP:Initialize()
    RLC.DKP:RequestGuildRoster(true)
    if RLC_DB.dkpUI.compact.visible then
      RLC.DKP:SetCompactVisible(true)
    end
    if RLC and RLC.ScheduleDeferred then
      RLC:ScheduleDeferred("rlc_dkp_login_sync", 8, function()
        if RLC and RLC.DKP and IsInGuild() and RLC.HasLeafAccess and RLC:HasLeafAccess() then
          RLC.DKP:RequestSync()
          RLC.DKP:RequestSnapshot()
        end
      end)
      RLC:ScheduleDeferred("rlc_dkp_admin_snapshot", 12, function()
        if RLC and RLC.DKP and IsInGuild() and RLC.DKP:CanAnswerSync() then
          RLC.DKP:BroadcastSnapshot()
        end
      end)
    end
  elseif currentEvent == "CHAT_MSG_ADDON" then
    RLC.DKP:HandleAddonMessage(arg1, arg2, arg4)
  elseif currentEvent == "GUILD_ROSTER_UPDATE" then
    RLC.DKP:MarkGuildRosterReady()
    RLC.DKP:RefreshAll()
  elseif currentEvent == "PLAYER_GUILD_UPDATE" then
    RLC.DKP:EnsureDB()
    RLC.DKP:RequestGuildRoster(true)
    RLC.DKP:RefreshAll()
  elseif currentEvent == "RAID_ROSTER_UPDATE" then
    RLC.DKP:RefreshAll()
  end
end)
