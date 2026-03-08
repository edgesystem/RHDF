storage = {}

--- Save garage data
---@param garageData table<string, GarageData>
function storage.SaveGarage(garageData)
    GarageZone = garageData
    TriggerClientEvent('rhd_garage:client:syncConfig', -1, GarageZone)
    SaveResourceFile(GetCurrentResourceName(), 'data/garages.json', json.encode(GarageZone), -1)
end

--- Save custom vehicle name data
---@param dataName table<string, CustomName>
function storage.SaveVehicleName(dataName)
    CNV = dataName
    SaveResourceFile(GetCurrentResourceName(), 'data/vehiclesname.json', json.encode(CNV), -1)
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    local garageFile = LoadResourceFile(GetCurrentResourceName(), 'data/garages.json')
    if garageFile then
        GarageZone = json.decode(garageFile) or {}
    else
        GarageZone = {}
    end

    local nameFile = LoadResourceFile(GetCurrentResourceName(), 'data/vehiclesname.json')
    if nameFile then
        CNV = json.decode(nameFile) or {}
    else
        CNV = {}
    end

    local count = 0
    for _ in pairs(GarageZone) do count = count + 1 end
    print(('[rhd_garage] %d garagens carregadas do disco.'):format(count))
end)