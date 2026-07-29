local VPS_IP = "103.176.79.8"
local PORT = "3000"

local placeId = tostring(game.PlaceId)

local requestUrl = string.format("http://%s:%s/api/script?placeId=%s", VPS_IP, PORT, placeId)
local success, response = pcall(function()
    return game:HttpGet(requestUrl)
end)
if success and response then
    local func, err = loadstring(response)
    if func then
        func()
    else
        warn("[Loader Error] Gagal Membaca Script: " .. tostring(err))
    end
else
    warn("[Loader Error] Gagal terhubung ke VPS Server!")
end