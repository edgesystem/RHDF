if not lib.checkDependency('ox_lib', '3.23.1') then error('This resource requires ox_lib version 3.23.1') end

--- callback
lib.callback.register('rhd_garage:cb_server:removeMoney', function(src, type, amount)
    return fw.rm(src, type, amount)
end)

lib.callback.register('rhd_garage:cb_server:getvehowner', function (src, plate, shared, pleaseUpdate)
    return fw.gvobp(src, plate, {
        owner = shared
    }, pleaseUpdate)
end)

lib.callback.register('rhd_garage:cb_server:getvehiclePropByPlate', function (_, plate)
    return fw.gpvbp(plate)
end)

lib.callback.register('rhd_garage:cb_server:getVehicleList', function(src, garage, impound, shared)
    return fw.gpvbg(src, garage, {
        impound = impound,
        shared = shared
    })
end)

lib.callback.register("rhd_garage:cb_server:swapGarage", function (source, clientData)
    return fw.svg(clientData.newgarage, clientData.plate)
end)

lib.callback.register("rhd_garage:cb_server:transferVehicle", function (src, clientData)
    if src == clientData.targetSrc then
        return false, locale("notify.error.cannot_transfer_to_myself")
    end

    local tid = clientData.targetSrc

    if not fw.rm(src, "cash", clientData.price) then
        return false, locale("notify.error.need_money", lib.math.groupdigits(clientData.price, '.'))
    end

    print("Transfer vehicle from " .. fw.gn(src) .. " to " .. fw.gn(tid))
    print("Plate: " .. clientData.plate)
    local success = fw.uvo(src, tid, clientData.plate)
    if success then utils.notify(tid, locale("notify.success.transferveh.target", fw.gn(src), clientData.garage), "success") end
    return success, locale("notify.success.transferveh.source", fw.gn(tid))
end)

lib.callback.register('rhd_garage:cb_server:getVehicleInfoByPlate', function (_, plate)
    return fw.gpvbp(plate)
end)

--- Event
RegisterNetEvent("rhd_garage:server:removeTemp", function ( data )
    if GetInvokingResource() then return end
    local citizenid = fw.gi(source)
    if not citizenid then return end
    if tempVehicle[citizenid] == data.model then
        tempVehicle[citizenid] = nil
    end
end)

lib.addCommand('removeTemp', {
    help = 'Recuperar garagem de player',
    restricted = 'group.admin',
    params = {
        { name = 'id', help = 'ID do player', type = 'number' }
    }
}, function(source, args)
    if args.id then
        local tid = tonumber(args.id)
        local citizenid = fw.gi(tid)
        local playerName = fw.gn(tid)
        if not citizenid then
            lib.notify(source, {description = "Jogador não encontrado.", type = "error", duration = 10000})
            return
        end
        tempVehicle[citizenid] = nil
        lib.notify(tid, {description = "Seus veículos de aluguel foram recuperados.", type = "success", duration = 10000})
        lib.notify(source, {description = "Garagem recuperada do id: " .. args.id .. " cidadão: " .. citizenid .. " de nome " .. playerName .. ".", type = "success", duration = 10000})
    else
        lib.notify(source, {description = "ID inválido.", type = "error", duration = 10000})
    end
end)

RegisterNetEvent("rhd_garage:server:updateState", function ( data )
    if GetInvokingResource() then return end
    fw.uvs(data.plate, data.state, data.garage)
end)

RegisterNetEvent("rhd_garage:server:saveGarageZone", function(fileData)
    if GetInvokingResource() then return end
    if type(fileData) ~= "table" or type(fileData) == "nil" then return end
    return storage.SaveGarage(fileData)
end)

RegisterNetEvent("rhd_garage:server:saveCustomVehicleName", function (fileData)
    if GetInvokingResource() then return end
    if type(fileData) ~= "table" or type(fileData) == "nil" then return end
    storage.SaveVehicleName(fileData)
    -- Persistir também no banco para sobreviver a restarts
    for plate, data in pairs(fileData) do
        if plate and data and data.name then
            MySQL.update(
                'UPDATE player_vehicles SET vehicle_name = ? WHERE plate = ?',
                { data.name, plate }
            )
        end
    end
end)

local vehicleSpawnCooldown = {}

lib.callback.register('rhd_garage:server:spawnVehicle', function(source, model, coords, props)
    local playerId = source

    if vehicleSpawnCooldown[playerId] then
        return false, false
    end

    vehicleSpawnCooldown[playerId] = true

    local netid, veh = qbx.spawnVehicle({
        model = model,
        spawnSource = coords,
        warp = false,
        props = props
    })

    SetTimeout(3000, function()
        vehicleSpawnCooldown[playerId] = nil
    end)

    return netid, veh
end)

--- exports
exports("Garage", function ()
    return GarageZone
end)
