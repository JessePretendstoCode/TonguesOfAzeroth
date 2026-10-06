-- Profile.lua -- export and import a whole configuration as a copy-safe string.
--
-- Why this exists. WoW names a saved variables file after the account, realm
-- and character it belongs to, so settings are welded to one character on one
-- client install. That is fine until the ground moves: a beta realm closes, a
-- character is rerolled under a new name, or you want the setup you spent an
-- evening building on one alt to exist on another. Copying files out of WTF
-- solves none of those, because the destination path does not exist yet or is
-- spelled differently.
--
-- A string does. You can paste it into any character on any client.
--
-- SECURITY, and the reason this file is longer than it looks like it needs to
-- be: the obvious way to serialise a Lua table is to write Lua source and read
-- it back with loadstring. That would mean every "profile code" a player is
-- handed on a forum is a program this addon runs with full access to their
-- client. So the format below is a token stream with no executable content and
-- a parser that only ever builds data. There is no eval here and there must
-- never be one.
--
-- The format, version 1:
--
--   GLYPHIC-P1-<base64 payload>-<checksum>
--
-- and the payload is a stream of self-delimiting tokens:
--
--   T                     true
--   F                     false
--   n<len>;<digits>       number, decimal text, %.17g so doubles round-trip
--   s<len>;<bytes>        string, length-prefixed so nothing needs escaping
--   t<count>;<pairs...>   table, count pairs, each a key value followed by a
--                         value value, both recursive
--
-- Length prefixes rather than delimiters are the whole trick: a player's
-- custom language can contain any byte at all, including whatever separator
-- we might have picked, and a length never has to be escaped.

local ADDON, ns = ...

local Language = ns.Language
local Compat = ns.Compat

local Profile = {}
ns.Profile = Profile

local fmt, rep, sub, byte = string.format, string.rep, string.sub, string.byte
local floor = math.floor
local tsort, tconcat = table.sort, table.concat

local PREFIX = "GLYPHIC-P1-"

-- Bounds. None of these should ever be reached by a real configuration; they
-- exist so a malformed or hostile string fails fast instead of allocating
-- until the client dies. The largest real config seen in testing was about
-- 4.6 KB of saved variables.
local MAX_DEPTH = 16
local MAX_PAYLOAD = 2 * 1024 * 1024
local MAX_COUNT = 100000

--=========================================================================--
--  Checksum
--=========================================================================--
-- FNV-1a, 32-bit, done in floating point because Lua 5.1 has no integer type
-- and no bitwise operators. The modulo keeps us inside the 2^53 range where
-- doubles are exact, so this is deterministic across clients.
--
-- This is a transcription check, not a security measure. Long strings get
-- truncated by chat windows, forum posts and spreadsheet cells all the time,
-- and a truncated base64 string usually still decodes -- into nonsense. The
-- checksum turns that silent corruption into a refusal.
local function checksum(s)
    local h = 2166136261
    for i = 1, #s do
        h = h - h % 1                      -- keep it integral
        h = (h + 0) % 4294967296
        h = h + byte(s, i)
        h = (h * 16777619) % 4294967296
    end
    return fmt("%08x", h)
end
Profile.Checksum = checksum

--=========================================================================--
--  Serialise
--=========================================================================--
-- Keys are emitted in a stable order so that exporting the same settings twice
-- produces the same string. Lua's pairs() order is arbitrary and can differ
-- between runs, which would make two identical configs look different and make
-- the tests non-deterministic.
local function keyOrder(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    if ta == "number" or ta == "string" then return a < b end
    return tostring(a) < tostring(b)
end

local function serialise(v, out, depth, skipped)
    if depth > MAX_DEPTH then
        error("profile nests deeper than " .. MAX_DEPTH .. " levels")
    end
    local t = type(v)
    if t == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif t == "number" then
        -- Reject what cannot survive the trip rather than writing "inf" and
        -- discovering on import that tonumber disagrees about it.
        if v ~= v or v == math.huge or v == -math.huge then
            return false
        end
        local s = fmt("%.17g", v)
        out[#out + 1] = "n" .. #s .. ";" .. s
    elseif t == "string" then
        out[#out + 1] = "s" .. #v .. ";" .. v
    elseif t == "table" then
        local keys = {}
        for k in pairs(v) do
            local tk = type(k)
            if tk == "string" or tk == "number" then
                keys[#keys + 1] = k
            else
                skipped[1] = skipped[1] + 1
            end
        end
        tsort(keys, keyOrder)

        -- Serialise the pairs first, because a value we cannot represent is
        -- dropped and that changes the count. Writing the count before knowing
        -- it would produce a stream the parser disagrees with.
        local body, n = {}, 0
        for i = 1, #keys do
            local k = keys[i]
            local piece = {}
            if serialise(v[k], piece, depth + 1, skipped) ~= false then
                serialise(k, body, depth + 1, skipped)
                body[#body + 1] = tconcat(piece)
                n = n + 1
            else
                skipped[1] = skipped[1] + 1
            end
        end
        out[#out + 1] = "t" .. n .. ";" .. tconcat(body)
    else
        -- Functions and userdata have no meaning on another machine.
        return false
    end
    return true
end

--=========================================================================--
--  Parse
--=========================================================================--
-- Strict by design. Every failure returns nil plus a reason rather than
-- guessing, because a profile that imports "mostly" is worse than one that
-- refuses: the player keeps the broken result and does not know what is
-- missing.
local function parseValue(s, pos, depth)
    if depth > MAX_DEPTH then return nil, nil, "nested too deeply" end
    local tag = sub(s, pos, pos)
    if tag == "" then return nil, nil, "ended early" end
    pos = pos + 1

    if tag == "T" then return true, pos end
    if tag == "F" then return false, pos end

    if tag == "n" or tag == "s" then
        local semi = s:find(";", pos, true)
        if not semi then return nil, nil, "missing length" end
        local len = tonumber(sub(s, pos, semi - 1))
        if not len or len < 0 or len ~= floor(len) then return nil, nil, "bad length" end
        local from = semi + 1
        local to = from + len - 1
        if to > #s then return nil, nil, "truncated" end
        local body = sub(s, from, to)
        if tag == "s" then return body, to + 1 end
        local num = tonumber(body)
        if not num then return nil, nil, "bad number" end
        return num, to + 1
    end

    if tag == "t" then
        local semi = s:find(";", pos, true)
        if not semi then return nil, nil, "missing table size" end
        local count = tonumber(sub(s, pos, semi - 1))
        if not count or count < 0 or count ~= floor(count) or count > MAX_COUNT then
            return nil, nil, "bad table size"
        end
        pos = semi + 1
        local out = {}
        for _ = 1, count do
            local k, v, err
            k, pos, err = parseValue(s, pos, depth + 1)
            if err then return nil, nil, err end
            if k == nil then return nil, nil, "nil key" end
            v, pos, err = parseValue(s, pos, depth + 1)
            if err then return nil, nil, err end
            out[k] = v
        end
        return out, pos
    end

    return nil, nil, "unknown token '" .. tag .. "'"
end

--=========================================================================--
--  Copying
--=========================================================================--
-- Deep copy so an imported table shares no structure with the string it came
-- from, and so an export is a snapshot rather than a live view that keeps
-- changing while the player stares at it.
local function deepCopy(v, depth)
    if type(v) ~= "table" or (depth or 0) > MAX_DEPTH then return v end
    local out = {}
    for k, val in pairs(v) do out[k] = deepCopy(val, (depth or 0) + 1) end
    return out
end
Profile.DeepCopy = deepCopy

--=========================================================================--
--  Export
--=========================================================================--
local function addonVersion()
    if Compat and Compat.GetAddOnMetadata then
        return Compat.GetAddOnMetadata(ADDON, "Version") or "?"
    end
    return "?"
end

local function whoAmI()
    local name = (UnitName and UnitName("player")) or "?"
    local realm = (GetRealmName and GetRealmName()) or nil
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

-- Returns code, info. `info.skipped` counts values that could not be
-- represented; it should always be zero and is surfaced so that if it ever
-- is not, somebody finds out.
function Profile.Export()
    local payload = {
        v = 1,
        addon = addonVersion(),
        char = whoAmI(),
        -- Recorded for the player's benefit when choosing between two codes.
        when = (date and date("%Y-%m-%d %H:%M")) or "",
        db = deepCopy(_G.GlyphicDB or {}),
    }

    local acct = _G.GlyphicAccountDB
    if type(acct) == "table" and type(acct.colors) == "table" then
        payload.colors = deepCopy(acct.colors)
    end

    local skipped = { 0 }
    local out = {}
    local ok, err = pcall(serialise, payload, out, 0, skipped)
    if not ok then return nil, tostring(err) end

    local body = Language.Base64Encode(tconcat(out))
    return PREFIX .. body .. "-" .. checksum(body), {
        skipped = skipped[1],
        char = payload.char,
        when = payload.when,
    }
end

--=========================================================================--
--  Import
--=========================================================================--
-- Parses and validates WITHOUT applying. Splitting the two is deliberate: the
-- player is asked to confirm an overwrite, and they should be told what they
-- are about to overwrite it WITH before they answer, not after.
function Profile.Parse(code)
    if type(code) ~= "string" then return nil, "no code given" end

    -- Pasted codes arrive wrapped in newlines, spaces and sometimes quotes,
    -- depending on where they travelled through.
    code = code:gsub("%s", ""):gsub('^"', ""):gsub('"$', "")
    if code == "" then return nil, "no code given" end

    if sub(code, 1, #PREFIX) ~= PREFIX then
        return nil, "that is not a Glyphic profile code"
    end
    local rest = sub(code, #PREFIX + 1)

    local dash = rest:match("^(.*)%-[0-9a-fA-F]+$")
    local sum = rest:match("%-([0-9a-fA-F]+)$")
    if not dash or not sum then return nil, "the code is missing its checksum" end
    if checksum(dash) ~= sum:lower() then
        return nil, "the code is damaged or incomplete -- copy the whole thing and try again"
    end

    local ok, raw = pcall(Language.Base64Decode, dash)
    if not ok or type(raw) ~= "string" or raw == "" then
        return nil, "the code could not be decoded"
    end
    if #raw > MAX_PAYLOAD then return nil, "that profile is implausibly large" end

    local value, pos, err = parseValue(raw, 1, 0)
    if err then return nil, "the code is malformed (" .. err .. ")" end
    if type(value) ~= "table" then return nil, "the code does not contain a profile" end
    if pos and pos <= #raw then return nil, "the code has trailing junk" end

    if value.v ~= 1 then
        return nil, "this code is version " .. tostring(value.v) ..
            ", which this build does not understand"
    end
    if type(value.db) ~= "table" then return nil, "the code has no settings in it" end

    return value
end

-- Replace, not merge. The player chose this and was warned; a merge would
-- leave a half-and-half state that is nobody's configuration and impossible
-- to reason about afterwards.
--
-- The tables are emptied and refilled IN PLACE rather than reassigned. Modules
-- that captured a reference to GlyphicDB or to one of its sub-tables at load
-- time would otherwise keep writing to the old table, and their settings would
-- quietly stop appearing.
local function replaceInPlace(target, source)
    for k in pairs(target) do target[k] = nil end
    for k, v in pairs(source) do target[k] = deepCopy(v) end
end

function Profile.Apply(parsed)
    if type(parsed) ~= "table" or type(parsed.db) ~= "table" then
        return false, "nothing to apply"
    end

    if type(_G.GlyphicDB) ~= "table" then _G.GlyphicDB = {} end
    replaceInPlace(_G.GlyphicDB, parsed.db)

    if type(parsed.colors) == "table" then
        if type(_G.GlyphicAccountDB) ~= "table" then _G.GlyphicAccountDB = {} end
        if type(_G.GlyphicAccountDB.colors) ~= "table" then _G.GlyphicAccountDB.colors = {} end
        replaceInPlace(_G.GlyphicAccountDB.colors, parsed.colors)
    end

    return true
end

-- Convenience for the slash command: parse, apply, report. The UI path keeps
-- the two steps apart so it can show the confirmation in between.
function Profile.Import(code)
    local parsed, err = Profile.Parse(code)
    if not parsed then return false, err end
    return Profile.Apply(parsed)
end
