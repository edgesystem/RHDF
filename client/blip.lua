gb = {}

local GarageBlip = {} ---@type table<string, integer>

--- Refresh Blip
---@param data table <string, GarageData>
function gb.refresh ( data )
    data = data or GarageZone
    if not data or type(data) ~= "table" then return end
    if GarageBlip and next(GarageBlip) then
        for k,v in pairs(GarageBlip) do
            if DoesBlipExist(v) then
                RemoveBlip(v)
            end
        end
    end

    GarageBlip = {}
    for k, v in pairs(data) do
        if v.blip then
            local location ---@as vector3
            local points = v.zones.points
           
            if type(points) == 'table' then
                for i=1, #points do
                    location = points[i]
                end
            end

            GarageBlip[k] = AddBlipForCoord(location.x, location.y, location.z)
            SetBlipSprite(GarageBlip[k], v.blip.type)
            SetBlipScale(GarageBlip[k], 0.9)
            SetBlipColour(GarageBlip[k], v.blip.color)
            SetBlipDisplay(GarageBlip[k], 4)
            SetBlipAsShortRange(GarageBlip[k], true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(v.blip.label or k)
            EndTextCommandSetBlipName(GarageBlip[k])
        end
    end
end

-- ================================================
-- GARAGE MARKERS - Ícone rotativo azul claro
-- ================================================
local _garageMarkerRotation = 0.0

CreateThread(function()
    while true do
        Wait(0)
        _garageMarkerRotation = (_garageMarkerRotation + 0.8) % 360.0
        local _plyCoords = GetEntityCoords(PlayerPedId())

        for _, garage in pairs(GarageZone) do
            if garage.zones and garage.zones.points and #garage.zones.points > 0 then
                local _gCoords = garage.zones.points[1]
                
                if _gCoords then
                    local _dist = #(_plyCoords - vector3(_gCoords.x, _gCoords.y, _gCoords.z))
                    if _dist < 60.0 then
                        DrawMarker(
                            36,
                            _gCoords.x, _gCoords.y, _gCoords.z,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, _garageMarkerRotation,
                            1.5, 1.5, 1.5,
                            30, 144, 255, 200,
                            false, true, 2, true,
                            nil, nil, false
                        )
                    end
                end
            end
        end
    end
end)
