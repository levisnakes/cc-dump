-- cc-dump: bundles every file on this computer (and attached disks) into one
-- archive and uploads it so you can read it on your PC.
-- Usage: dump            -> Discord webhook if set, else catbox.moe
--        dump catbox     -> catbox.moe link (permanent)
--        dump litterbox  -> litterbox link (deleted after 72h)
--        dump discord    -> Discord webhook only
--        dump local      -> just write /ccdump.txt

DISCORD_WEBHOOK = ""          -- optional, /config.lua overrides this
SKIP = { "/rom", "/ccdump.txt" }
MAX_FILE = 4 * 1024 * 1024    -- skip single files bigger than this

-- ==== code ====
local cfg = {}
if fs.exists("/config.lua") then
  local f = loadfile("/config.lua", "t", setmetatable(cfg, { __index = _ENV }))
  if f then pcall(f) end
end
local webhook = rawget(cfg, "DISCORD_WEBHOOK") or DISCORD_WEBHOOK
local mode = ({ ... })[1] or "auto"

local function skipped(path)
  for _, s in ipairs(SKIP) do
    if path == s or path:sub(1, #s + 1) == s .. "/" then return true end
  end
  return false
end

-- walk the filesystem
local files, dirs, skippedBig = {}, 0, {}
local function walk(dir)
  for _, name in ipairs(fs.list(dir)) do
    local path = (dir == "/" and "" or dir) .. "/" .. name
    if not skipped(path) then
      if fs.isDir(path) then
        dirs = dirs + 1
        walk(path)
      elseif fs.getSize(path) > MAX_FILE then
        skippedBig[#skippedBig + 1] = path
      else
        files[#files + 1] = path
      end
    end
  end
end
walk("/")
table.sort(files)

-- build the archive: readable as plain text, and every file's byte length is
-- in its header so unpack.py can split it exactly
local parts, total = {}, 0
local label = os.getComputerLabel() or "(no label)"
parts[#parts + 1] = ("==== CCDUMP v1 ====\ncomputer: %d\nlabel: %s\nday: %d  time: %s\nfiles: %d  dirs: %d\n")
  :format(os.getComputerID(), label, os.day(), textutils.formatTime(os.time(), true), #files, dirs)
for _, p in ipairs(skippedBig) do parts[#parts + 1] = "skipped (too big): " .. p .. "\n" end
parts[#parts + 1] = "\n-- file list --\n"
for _, p in ipairs(files) do parts[#parts + 1] = ("%8d  %s\n"):format(fs.getSize(p), p) end

for _, p in ipairs(files) do
  local h = fs.open(p, "rb")
  local data = ""
  if h then data = h.readAll() or ""; h.close() end
  total = total + #data
  parts[#parts + 1] = ("\n==== FILE %s %d ====\n"):format(p, #data)
  parts[#parts + 1] = data
  parts[#parts + 1] = "\n==== END ====\n"
end
local archive = table.concat(parts)

local out = fs.open("/ccdump.txt", "wb")
out.write(archive)
out.close()
print(("Packed %d files (%d bytes) -> /ccdump.txt"):format(#files, total))
if #skippedBig > 0 then print("Skipped " .. #skippedBig .. " huge file(s)") end
if mode == "local" then return end

local fname = ("ccdump_%d_%s.txt"):format(os.getComputerID(), label:gsub("[^%w%-_]", "_"))

local function multipart(fields, fileField, fileName, fileData)
  local b = "----ccdump" .. tostring(math.random(1e9))
  local t = {}
  for k, v in pairs(fields) do
    t[#t + 1] = "--" .. b .. '\r\nContent-Disposition: form-data; name="' .. k .. '"\r\n\r\n' .. v .. "\r\n"
  end
  t[#t + 1] = "--" .. b .. '\r\nContent-Disposition: form-data; name="' .. fileField ..
    '"; filename="' .. fileName .. '"\r\nContent-Type: text/plain\r\n\r\n'
  t[#t + 1] = fileData
  t[#t + 1] = "\r\n--" .. b .. "--\r\n"
  return table.concat(t), "multipart/form-data; boundary=" .. b
end

local function post(url, body, ctype)
  local res, err, errRes = http.post({ url = url, body = body, binary = true,
    headers = { ["Content-Type"] = ctype, ["User-Agent"] = "cc-dump" } })
  local r = res or errRes
  local text = r and r.readAll() or ""
  if r then r.close() end
  if not res then return nil, (err or "failed") .. " " .. text:sub(1, 200) end
  return text
end

local function toDiscord()
  if webhook == "" then return nil, "no DISCORD_WEBHOOK set" end
  if #archive > 9.5 * 1024 * 1024 then return nil, "too big for Discord" end
  local body, ct = multipart(
    { payload_json = textutils.serializeJSON({ content = ("CC dump of computer %d (%s): %d files")
      :format(os.getComputerID(), label, #files) }) },
    "files[0]", fname, archive)
  local ok, err = post(webhook, body, ct)
  if not ok then return nil, err end
  return "sent to Discord webhook"
end

local function toCatbox(litter)
  local url = litter and "https://litterbox.catbox.moe/resources/internals/api.php"
    or "https://catbox.moe/user/api.php"
  local fields = { reqtype = "fileupload" }
  if litter then fields.time = "72h" end
  local body, ct = multipart(fields, "fileToUpload", fname, archive)
  local text, err = post(url, body, ct)
  if not text then return nil, err end
  text = text:gsub("%s+$", "")
  if not text:match("^https?://") then return nil, text:sub(1, 200) end
  return text
end

local tries
if mode == "discord" then tries = { "discord" }
elseif mode == "catbox" then tries = { "catbox", "litterbox" }
elseif mode == "litterbox" then tries = { "litterbox" }
else
  tries = webhook ~= "" and { "discord", "catbox", "litterbox" } or { "catbox", "litterbox" }
end

for _, t in ipairs(tries) do
  write("Uploading to " .. t .. "... ")
  local ok, err
  if t == "discord" then ok, err = toDiscord() else ok, err = toCatbox(t == "litterbox") end
  if ok then
    print("done")
    term.setTextColor(colors.lime)
    print(ok)
    term.setTextColor(colors.white)
    return
  end
  print("failed: " .. tostring(err))
end
print("All uploads failed. The archive is still at /ccdump.txt")
