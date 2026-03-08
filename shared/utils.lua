utils = {}
utils.string = {}

local server = IsDuplicityVersion()

---@param rot vector3
local RotationToDirection = function(rot)
    local rotZ = math.rad(rot.z)
    local rotX = math.rad(rot.x)
    local cosOfRotX = math.abs(math.cos(rotX))
    return vector3(-math.sin(rotZ) * cosOfRotX, math.cos(rotZ) * cosOfRotX, math.sin(rotX))
end

function utils.string.trim(s)
    if not s or type(s) ~= 'string' then return end
    local trimmed = s:gsub('^%s*(.-)%s*$', '%1')
    return trimmed
end

function utils.string.isEmpty(s)
    return s:match("^%s*$")
end

function utils.raycastCam(distance)
    local camRot = GetGameplayCamRot()
    local camPos = GetGameplayCamCoord()
    local dir = RotationToDirection(camRot)
    local dest = camPos + (dir * distance)
    local ray = StartShapeTestRay(camPos, dest, 17, -1, 0)
    local _, hit, endPos = GetShapeTestResult(ray)
    if hit == 0 then endPos = dest end
    local inwater, watercoords = TestProbeAgainstWater(camPos.x, camPos.y, camPos.z, endPos.x, endPos.y, endPos.z)
    return hit, endPos, inwater, watercoords
end

function utils.notify(msg, type, duration)
    lib.notify({
        description = msg,
        type = type,
        duration = duration or 5000
    })
end

function utils.drawtext (type, text, icon)
    if type == 'show' then
        lib.showTextUI(text,{
            position = "right-center",
            icon = icon or '',
            style = {
                borderRadius= 5,
            }
        })
    elseif type == 'hide' then
        lib.hideTextUI()
    end
end

function utils.createMenu( data )
    lib.registerContext(data)
    lib.showContext(data.id)
end

utils.previewCam = nil

function utils.createPreviewCam(vehicle)
    if not DoesEntityExist(vehicle) then return end

    if not Config.DisableVehicleCamera then
        local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        utils.previewCam = cam
        RenderScriptCams(true, true, 1500,  true,  true)

        local vehpos = GetEntityCoords(vehicle)
        local pos = GetOffsetFromEntityInWorldCoords(vehicle, 4.0, 7.0, 1.0)
        local camF = GetGameplayCamFov()

        SetCamCoord(cam, pos.x, pos.y, pos.z + 1.2)
        PointCamAtCoord(cam, vehpos.x, vehpos.y, vehpos.z + 0.2)
        SetCamFov(cam, camF - 20)
    end
end

function utils.destroyPreviewCam(vehicle, enterVehicle)
    if not DoesEntityExist(vehicle) then return end

    if utils.previewCam then
        if enterVehicle then
            DoScreenFadeOut(500)
            Wait(1000)
            DoScreenFadeIn(500)
        end

        RenderScriptCams(false, true, 1500, false, false)
        DestroyCam(utils.previewCam, true)
        utils.previewCam = nil
    end
end

function utils.createTargetPed(model, coords, options)
    local newoptions = {}
    local qbtd = nil --- qb-target distance options
    
    lib.requestModel(model, 150000)
    local ped = CreatePed(0, model, coords.x, coords.y, coords.z - 1, coords.w, false, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)

    if type(options) == "table" and #options > 0 then
        for i=1, #options do
            local data = options[i]
            local opt = {
                name = data.name,
                label = data.label,
                icon = data.icon,
            }
            if Config.Target == "ox" then
                opt.groups = data.groups
                opt.distance = data.distance
                opt.onSelect = data.action
            elseif Config.Target == "qb" then
                opt.job = data.groups
                opt.gang = data.groups
                opt.action = data.action
            end
            qbtd = data.distance
            newoptions[#newoptions+1] = opt
        end
    end

    if #newoptions > 0 then
        if Config.Target == "ox" then
            exports.ox_target:addLocalEntity(ped, newoptions)
        elseif Config.Target == "qb" then
            local param = {
                options = newoptions,
                distance = qbtd
            }
            exports['qb-target']:AddTargetEntity(ped, param)
        end
    end

    return ped
end

function utils.removeTargetPed(entity, label)
    if DoesEntityExist(entity) then
        if Config.Target == "ox" then
            exports.ox_target:removeLocalEntity(entity, label)
            DeleteEntity(entity)
        elseif Config.Target == "qb" then
            exports['qb-target']:RemoveTargetEntity(entity, label)
            DeleteEntity(entity)
        end
    end
end

function utils.getColorLevel(level)
    if not level then return end
    return level < 25 and "red" or level >= 25 and level < 50 and  "#E86405" or level >= 50 and level < 75 and "#E8AC05" or level >= 75 and "green"
end

function utils.getPlate ( vehicle )
    if not DoesEntityExist(vehicle) then return end
    local vehPlate = GetVehicleNumberPlateText(vehicle)
    return utils.string.trim(vehPlate)
end

function utils.getCategoryByClass ( vehType )
    local class = {
        [8] = "motorcycle",
        [13] = "cycles",
        [14] = "boat",
        [15] = "helicopter",
        [16] = "planes",
    }
    return class[vehType] or "car"
end


function utils.setFuel(vehicle, fuel)
    Wait(100)
    if Config.FuelScript == "ox_fuel" then
        Entity(vehicle).state.fuel = fuel or 100
    else
        exports[Config.FuelScript]:SetFuel(vehicle, fuel or 100)
    end
end

function utils.getFuel(vehicle)
    local fuelLevel = 0
    if Config.FuelScript == "ox_fuel" then
        fuelLevel = Entity(vehicle).state?.fuel or 100 
    else
        fuelLevel = exports[Config.FuelScript]:GetFuel(vehicle)
    end
    return fuelLevel
end

function utils.createPlyVeh ( model, coords, cb, network, props )
    network = network == nil and false or network
    lib.requestModel(model, 150000)
    local netid = lib.callback.await("rhd_garage:server:spawnVehicle", false, model, coords, props)
    if not netid then 
        return lib.notify({description = "Você deve esperar um pouco para fazer essa ação novamente", type = "error", duration = 10000})    
    end
    local veh = NetworkGetEntityFromNetworkId(netid)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetModelAsNoLongerNeeded(model)
    if cb then cb(veh) else return veh end
end

function utils.createPreviewVeh ( model, coords, cb, network )
    network = network == nil and true or network
    lib.requestModel(model, 150000)
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, network, false)
    if network then
        local id = NetworkGetNetworkIdFromEntity(veh)
        SetNetworkIdCanMigrate(id, true)
        SetEntityAsMissionEntity(veh, true, true)
    end
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetModelAsNoLongerNeeded(model)
    if cb then cb(veh) else return veh end
end

function utils.garageType ( data )
    local result = ""
    for i=1, #data do
        local class = data[i]
        result = result .. ("%s%s"):format(class, data[i + 1] and ", " or "")
    end
    return result
end

function utils.GangCheck ( data )
    local configGang = data.gang
    local playergang = fw.player.gang
    local allowed = false
    if type(configGang) == 'table' then
        local grade = configGang[playergang.name]
        allowed = grade and playergang.grade >= grade
    elseif type(configGang) == 'string' then
        if playergang.name == configGang then
            allowed = true
        end
    end
    return allowed
end

function utils.JobCheck ( data )
    local configJob = data.job
    local playerjob = fw.player.job
    local allowed = false

    if type(configJob) == 'table' then
        local grade = configJob[playerjob.name]
        allowed = grade and playerjob.grade >= grade
    elseif type(configJob) == 'string' then
        if playerjob.name == configJob then
            allowed = true
        end
    end
    return allowed
end

if server then
    function utils.notify(src, msg, type, duration)
        lib.notify(src, {
            description = msg,
            type = type,
            duration = duration or 5000
        })
    end
end