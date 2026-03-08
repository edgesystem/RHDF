# PROMPT CIRÚRGICO — rhd_garage Bug Fix
## Para: Kilo Code | Tarefa: Correções precisas sem refatoração

---

## CONTEXTO OBRIGATÓRIO — LEIA ANTES DE QUALQUER EDIÇÃO

Você está corrigindo o resource FiveM `rhd_garage`.
Framework: **QBX/QBCore** (Lua 5.4, FiveM natives).
Dependências: `ox_lib`, `fivem-freecam`, `oxmysql`.

**REGRAS ABSOLUTAS:**
- NÃO renomear funções, eventos, exports ou variáveis globais existentes
- NÃO mover arquivos de lugar
- NÃO alterar lógica de negócio (autorização, jobs, gangs, shared)
- NÃO alterar a estrutura do banco de dados
- Cada correção é ISOLADA — aplique uma de cada vez e valide
- Se uma linha não está listada aqui, NÃO a toque
- Comentários de código: apenas onde explicitamente indicado

---

## MAPA DE ARQUIVOS RELEVANTES

```
rhd_garage/
├── client/
│   └── main.lua          ← CORRIGIR: bugs #1, #4, #5, #6
├── server/
│   ├── main.lua          ← CORRIGIR: bug #3, #7
│   └── storage.lua       ← CORRIGIR: bug #2
└── modules/
    ├── deformation.lua   ← CORRIGIR: bug #8
    └── spawnpoint.lua    ← CORRIGIR: bug #9
```

---

## BUG #1 — CRÍTICO | `client/main.lua` — Guard `while not vehEntity` está nas linhas erradas

### Diagnóstico preciso
`utils.createPlyVeh` é assíncrono (callback). O callback `function(veh) vehEntity = veh end` só é chamado quando o modelo carrega e o servidor confirma o spawn. As linhas 78–99 usam `vehEntity` ANTES que o guard da linha 95 execute. Resultado: `vehEntity = nil` em todas essas chamadas → engine health, body, fuel, deformation e `vehlabel` nunca são aplicados ao veículo.

### Localização exata
Arquivo: `client/main.lua`

**Bloco atual (linhas 75–99):**
```lua
local vehEntity
utils.createPlyVeh(vehData.model, data.coords, function(veh) vehEntity = veh end, true, vehData.mods)

SetVehicleOnGroundProperly(vehEntity)

if (not vehData.mods or json.encode(vehData.mods) == "[]") and
    (not data.prop or json.encode(data.prop) == "[]") and
    data.plate then
    SetVehicleNumberPlateText(vehEntity, data.plate)
    TriggerEvent("vehiclekeys:client:SetOwner", data.plate)
end

SetVehicleEngineHealth(vehEntity, (vehData.engine or 1000) + 0.0)
SetVehicleBodyHealth(vehEntity, (vehData.body or 1000) + 0.0)
utils.setFuel(vehEntity, vehData.fuel or 100)

if vehData.deformation or data.deformation then
    Deformation.set(vehEntity, vehData.deformation or data.deformation)
end

while not vehEntity do
    Wait(100)
end

Entity(vehEntity).state:set('vehlabel', vehData.vehicle_name or data.vehicle_name)
```

**Substituir EXATAMENTE por:**
```lua
local vehEntity
utils.createPlyVeh(vehData.model, data.coords, function(veh) vehEntity = veh end, true, vehData.mods)

-- Aguarda o veículo existir antes de qualquer operação
while not vehEntity do
    Wait(100)
end

SetVehicleOnGroundProperly(vehEntity)

if (not vehData.mods or json.encode(vehData.mods) == "[]") and
    (not data.prop or json.encode(data.prop) == "[]") and
    data.plate then
    SetVehicleNumberPlateText(vehEntity, data.plate)
    TriggerEvent("vehiclekeys:client:SetOwner", data.plate)
end

SetVehicleEngineHealth(vehEntity, (vehData.engine or 1000) + 0.0)
SetVehicleBodyHealth(vehEntity, (vehData.body or 1000) + 0.0)
utils.setFuel(vehEntity, vehData.fuel or 100)

if vehData.deformation or data.deformation then
    Deformation.set(vehEntity, vehData.deformation or data.deformation)
end

Entity(vehEntity).state:set('vehlabel', vehData.vehicle_name or data.vehicle_name)
```

**Validação:** Após a correção, spawnar um veículo tunado e verificar que as modificações aparecem corretamente. Motor danificado deve aparecer danificado.

---

## BUG #2 — CRÍTICO | `server/storage.lua` — GarageZone nunca carrega do disco no boot

### Diagnóstico preciso
`storage.SaveGarage` salva em `data/garages.json` e `storage.SaveVehicleName` salva em `data/vehiclesname.json`. Porém não existe nenhum `AddEventHandler('onResourceStart')` que leia esses arquivos de volta. Após qualquer restart do resource, `GarageZone = nil` e `CNV = nil`. Todas as garagens criadas pelo editor in-game desaparecem. O `syncConfig` nunca é disparado para jogadores que entram após o restart.

### Localização exata
Arquivo: `server/storage.lua`

**ADICIONAR ao final do arquivo, após a última função:**
```lua
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
```

**NÃO alterar** as funções `SaveGarage` e `SaveVehicleName` existentes.

**Validação:** Criar uma garagem via `/garagelist`, reiniciar o resource com `restart rhd_garage`, verificar que a garagem ainda aparece no mundo.

---

## BUG #3 — ALTO | `server/main.lua` — `vehicle_name` customizado nunca persiste no banco de dados

### Diagnóstico preciso
O evento `rhd_garage:server:saveCustomVehicleName` chama apenas `storage.SaveVehicleName(fileData)` que grava somente em `data/vehiclesname.json`. A coluna `vehicle_name` em `player_vehicles` nunca é atualizada. Após restart ou quando um jogador novo entra no servidor (que não tem o JSON em memória), o nome customizado some.

### Localização exata
Arquivo: `server/main.lua`

**Bloco atual:**
```lua
RegisterNetEvent("rhd_garage:server:saveCustomVehicleName", function (fileData)
    if GetInvokingResource() then return end
    if type(fileData) ~= "table" or type(fileData) == "nil" then return end
    return storage.SaveVehicleName(fileData)
end)
```

**Substituir EXATAMENTE por:**
```lua
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
```

**Validação:** Trocar o nome de um veículo, reiniciar o resource, abrir a garagem e verificar que o nome aparece corretamente no menu.

---

## BUG #4 — ALTO | `client/main.lua` — Race condition: veículo deletado antes do server confirmar o store

### Diagnóstico preciso
Em `storeVeh()`, `DeleteVehicle` e `DeleteEntity` são chamados antes de `TriggerServerEvent('rhd_garage:server:updateState')`. `TriggerServerEvent` é fire-and-forget. Em condições de lag de rede, o servidor pode processar o `updateState` depois que outro jogador já abriu o menu da garagem, vendo o veículo como `stored=0` (fora). Isso cria duplicatas de veículo no mundo.

### Localização exata
Arquivo: `client/main.lua` — função `storeVeh`, bloco final dentro do `if DoesEntityExist(vehicle) then`

**Bloco atual:**
```lua
    if DoesEntityExist(vehicle) then
        if GetResourceState('tokyo_Qcarkeys') == 'started' and Config.GiveKeys.onspawn then
            exports.tokyo_Qcarkeys:RemoveKeyItem(plate)
        end
        
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        local veh = NetworkGetEntityFromNetworkId(netId)
        SetNetworkIdCanMigrate(netId, true)
        if veh and DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
        end
        
        if vehicle and DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
        
        TriggerServerEvent('rhd_garage:server:updateState', {plate = plate, state = 1, garage = data.garage})
        utils.notify(locale('notify.success.store_veh'), 'success')
    end
```

**Substituir EXATAMENTE por:**
```lua
    if DoesEntityExist(vehicle) then
        if GetResourceState('tokyo_Qcarkeys') == 'started' and Config.GiveKeys.onspawn then
            exports.tokyo_Qcarkeys:RemoveKeyItem(plate)
        end

        -- Avisar o servidor ANTES de deletar para evitar race condition
        TriggerServerEvent('rhd_garage:server:updateState', {plate = plate, state = 1, garage = data.garage})
        Wait(150)

        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        local veh = NetworkGetEntityFromNetworkId(netId)
        SetNetworkIdCanMigrate(netId, true)
        if veh and DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
        end
        
        if vehicle and DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
        
        utils.notify(locale('notify.success.store_veh'), 'success')
    end
```

**Validação:** Guardar veículo com outro jogador olhando a garagem ao mesmo tempo. O veículo não deve aparecer duplicado.

---

## BUG #5 — ALTO | `client/main.lua` — fakeplate substitui plate real antes da query no banco

### Diagnóstico preciso
Em `openMenu()`, a linha `plate = fakeplate or plate` sobrescreve a placa real com a fakeplate. Quando `actionMenu` → `spawnvehicle` é chamado, `data.plate = fakeplate`. O callback `getvehiclePropByPlate` busca no banco por `plate = fakeplate`, mas `player_vehicles` é indexado pela placa real. A query não encontra o registro e `callbackData = nil`, causando `error('Failed to load vehicle data...')` e o spawn falha silenciosamente.

### Localização exata
Arquivo: `client/main.lua` — dentro do `for i = 1, #vehData do` em `openMenu()`

**Bloco atual (encontre estas linhas exatas):**
```lua
        local plate = utils.string.trim(vd.plate)
        local vehDeformation = vd.deformation
        local gState = vd.state
        local pName = vd.owner or "Unkown Players"
        local fakeplate = vd.fakeplate and utils.string.trim(vd.fakeplate)
```
...e mais abaixo:
```lua
        plate = fakeplate or plate
```
...e no `actionMenu(...)` chamado dentro do `onSelect`:
```lua
                    actionMenu({
                        prop = vehProp,
                        engine = engine,
                        fuel = fuel,
                        body = body,
                        model = vehModel,
                        plate = plate,
```

**Correção em 3 partes:**

**Parte 5A** — Adicionar variável `realplate` logo após a declaração de `plate`:
```lua
        local plate = utils.string.trim(vd.plate)
        local realplate = plate  -- preservar placa real para queries no DB
        local vehDeformation = vd.deformation
        local gState = vd.state
        local pName = vd.owner or "Unkown Players"
        local fakeplate = vd.fakeplate and utils.string.trim(vd.fakeplate)
```

**Parte 5B** — Manter a linha `plate = fakeplate or plate` para exibição na UI (não alterar).

**Parte 5C** — No `actionMenu({...})` dentro do `onSelect`, trocar `plate = plate` por `plate = realplate`:
```lua
                    actionMenu({
                        prop = vehProp,
                        engine = engine,
                        fuel = fuel,
                        body = body,
                        model = vehModel,
                        plate = realplate,
```

**ATENÇÃO:** O `vehicleLabel` que usa `plate` para exibição na UI deve continuar usando `plate` (fakeplate). Só o campo `plate` dentro de `actionMenu({})` muda para `realplate`.

**Validação:** Com um veículo que tenha fakeplate cadastrada, abrir a garagem e dar spawn. O veículo deve spawnar normalmente com as mods e dados corretos.

---

## BUG #6 — MÉDIO | `client/main.lua` — `assert` crash em garagens sem `spawnPoint`

### Diagnóstico preciso
`getAvailableSP()` contém um `assert` que crasha quando `points` é `nil` ou vazio. Cinco garagens no `garages.json` não têm `spawnPoint` definido: **"Redline Executivo"**, **"Bennys Executivo"**, **"Tático Heliponto"**, **"FARM - CARTEL"**, **"SAMU HELIPONTO 2"**. Quando qualquer jogador tenta interagir com essas garagens, o script client para de executar completamente para esse jogador.

### Localização exata
Arquivo: `client/main.lua` — função `getAvailableSP`

**Bloco atual:**
```lua
local function getAvailableSP(points, ignoreDist, defaultCoords)
    if type(points) ~= "table" and ignoreDist then
        return points
    end
    assert(
        type(points) == "table" and points[1], 'Invalid "points" parameter: Expected a non-empty array table.'
    )
```

**Substituir EXATAMENTE por:**
```lua
local function getAvailableSP(points, ignoreDist, defaultCoords)
    if type(points) ~= "table" and ignoreDist then
        return points
    end
    if not points or type(points) ~= "table" or not points[1] then
        return nil
    end
```

**Validação:** Abrir o menu de qualquer uma das 5 garagens listadas. Deve exibir a notify de erro `locale('notify.error.no_parking_spot')` em vez de crashar o script.

---

## BUG #7 — MÉDIO | `server/main.lua` — `exports.qbx_core` hardcoded em eventos críticos

### Diagnóstico preciso
Dois lugares no `server/main.lua` chamam `exports.qbx_core:GetPlayer()` diretamente, ignorando o bridge `fw`. Em servidores ESX ou QBCore puro (sem QBX), isso causa `attempt to index a nil value` e derruba o script server-side.

### Localização exata
Arquivo: `server/main.lua`

**Ocorrência 1 — evento `removeTemp`:**
```lua
RegisterNetEvent("rhd_garage:server:removeTemp", function ( data )
    if GetInvokingResource() then return end
    local player = exports.qbx_core:GetPlayer(source)
    local citizenid = player.PlayerData.citizenid
    if tempVehicle[citizenid] == data.model then
        tempVehicle[citizenid] = nil
    end
end)
```

**Substituir EXATAMENTE por:**
```lua
RegisterNetEvent("rhd_garage:server:removeTemp", function ( data )
    if GetInvokingResource() then return end
    local citizenid = fw.gi(source)
    if not citizenid then return end
    if tempVehicle[citizenid] == data.model then
        tempVehicle[citizenid] = nil
    end
end)
```

**Ocorrência 2 — comando `removeTemp`:**
```lua
lib.addCommand('removeTemp', {
    help = 'Recuperar garagem de player',
    restricted = 'group.admin',
    params = {
        { name = 'id', help = 'ID do player', type = 'number' }
    }
}, function(source, args)
    if args.id then
        local player = exports.qbx_core:GetPlayer(tonumber(args.id))
        local citizenid = player.PlayerData.citizenid
        tempVehicle[citizenid] = nil
        lib.notify(tonumber(args.id), {description = "Seus veículos de aluguel foram recuperados.", type = "success", duration = 10000})
        lib.notify(source, {description = "Garagem recuperada do id: " .. args.id .. " cidadão: " .. citizenid .. " de nome " .. player.PlayerData.name .. ".", type = "success", duration = 10000})
    else
        lib.notify(source, {description = "ID inválido.", type = "error", duration = 10000})
    end
end)
```

**Substituir EXATAMENTE por:**
```lua
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
```

**ATENÇÃO:** Verifique na bridge `fw` se `fw.gi(source)` retorna apenas o `citizenid` (sem o segundo argumento `true` que retorna também a license). Se a assinatura for `fw.gi(source, returnLicense)`, use `fw.gi(tid)` sem o segundo argumento para obter só o citizenid.

**Validação:** Em servidor ESX, executar o comando `/removeTemp <id>`. Não deve gerar erro de nil index.

---

## BUG #8 — MÉDIO | `modules/deformation.lua` — `SetVehicleDamage` sem `Wait` entre chamadas

### Diagnóstico preciso
`Deformation.set` itera sobre 28 offsets e chama `SetVehicleDamage` 28 vezes consecutivas no mesmo frame. O motor físico do GTA (Bullet Physics) não processa danos sobrepostos no mesmo tick — os últimos danos sobrescrevem os anteriores no buffer. Resultado: a deformação salva e a aplicada são diferentes. Veículos aparecem menos danificados do que estavam ao ser guardados.

### Localização exata
Arquivo: `modules/deformation.lua` — função `Deformation.set`

**Bloco atual:**
```lua
    if deformation and next(deformation) then
        for k, v in pairs(deformation) do
			local x, y, z, d = v.offset.x, v.offset.y, v.offset.z, (v.damage * damageMult)
			if d > 14.0 then
				d  = 14.5
			end
            SetVehicleDamage(vehicle, x, y, z, d, 1000.0, true)
        end
    end
```

**Substituir EXATAMENTE por:**
```lua
    if deformation and next(deformation) then
        for k, v in pairs(deformation) do
            local x, y, z, d = v.offset.x, v.offset.y, v.offset.z, (v.damage * damageMult)
            if d > 14.0 then
                d = 14.5
            end
            if d > 0.0 then
                SetVehicleDamage(vehicle, x, y, z, d, 1000.0, true)
                Wait(0)
            end
        end
    end
```

**Por que `Wait(0)` e não `Wait(1)`:** `Wait(0)` cede o frame para o motor processar sem adicionar atraso perceptível. `if d > 0.0` evita processar os 28 pontos sem dano (a maioria em veículos intactos), tornando o loop mais eficiente.

**Validação:** Bater um veículo até deformar, guardar na garagem, retirar. A deformação deve corresponder ao estado anterior.

---

## BUG #9 — BAIXO | `modules/spawnpoint.lua` — `svp` usa índice de `vc` após inserção, dessincronizando em edge case

### Diagnóstico preciso
Na inserção de spawn point:
```lua
vc[#vc+1] = rc      -- insere: #vc agora é N+1
svp[#vc] = vm       -- usa N+1 como índice: correto na maioria dos casos
vehCreated[#vehCreated+1] = pv
```
O problema ocorre quando `vc`, `svp` e `vehCreated` ficam dessincronizados por qualquer operação intermediária. A forma segura é usar uma variável de índice explícita.

### Localização exata
Arquivo: `modules/spawnpoint.lua` — dentro do `if IsDisabledControlJustPressed(0, 22) then` → `if inZone then`

**Bloco atual:**
```lua
                    if inZone then
                        local rc = vec4(CurrentCoords.x, CurrentCoords.y, CurrentCoords.z, heading)
                        local vm = NVL[vehType][vehIndex]
                        local pv = createPV(vm, rc)
                        
                        vc[#vc+1] = rc
                        svp[#vc] = vm
                        
                        vehCreated[#vehCreated+1] = pv
                        utils.notify("location successfully created " .. #vc, "success", 8000)
                    else
```

**Substituir EXATAMENTE por:**
```lua
                    if inZone then
                        local rc = vec4(CurrentCoords.x, CurrentCoords.y, CurrentCoords.z, heading)
                        local vm = NVL[vehType][vehIndex]
                        local pv = createPV(vm, rc)

                        local newIdx = #vc + 1
                        vc[newIdx] = rc
                        svp[newIdx] = vm
                        vehCreated[#vehCreated + 1] = pv
                        utils.notify("location successfully created " .. newIdx, "success", 8000)
                    else
```

**Validação:** Criar uma garagem com múltiplos spawn points, adicionar e remover pontos. Os modelos de veículo preview devem corresponder aos spawn points corretos.

---

## ORDEM DE APLICAÇÃO RECOMENDADA

Aplique nesta ordem para facilitar validação incremental:

```
1. server/storage.lua   → Bug #2 (base de tudo, garagens precisam carregar)
2. client/main.lua      → Bug #1 (mais crítico, afeta todos os spawns)
3. client/main.lua      → Bug #6 (previne crash que bloqueia outros testes)
4. server/main.lua      → Bug #3 (nome customizado no DB)
5. client/main.lua      → Bug #4 (race condition no store)
6. client/main.lua      → Bug #5 (fakeplate)
7. server/main.lua      → Bug #7 (qbx_core hardcoded)
8. modules/deformation.lua → Bug #8 (deformation com Wait)
9. modules/spawnpoint.lua  → Bug #9 (índice svp)
```

---

## O QUE NÃO TOCAR

Os arquivos abaixo estão corretos e não devem ser modificados:
- `modules/zone.lua` — lógica do creator de zona está correta
- `modules/debugzone.lua` — utilitário de debug apenas
- `modules/pedcreator.lua` — lógica correta
- `client/vehicle.lua` — funções de veículo corretas
- `client/zone.lua` — lógica de zonas correta
- `client/blip.lua` — blips corretos (exceto o CreateThread que roda mesmo sem garagens, inofensivo)
- `server/vehicle.lua` — correto
- `server/police_impound.lua` — correto
- `server/command.lua` — correto
- `server/db_update.lua` — correto
- `server/jobvehshop.lua` — correto
- `client/creator.lua` — correto
- `sql/qb.sql` — correto
- `sql/rhd_garage_policeimpound.sql` — correto

---

## VERIFICAÇÃO FINAL

Após todas as correções, testar este fluxo completo:

1. `restart rhd_garage` → garagens devem aparecer (Bug #2)
2. Abrir garagem → veículo com mods deve aparecer no preview com mods (visual)
3. Spawn veículo → engine/body/fuel/deformation corretos (Bug #1 + #8)
4. Guardar veículo → sem duplicata, state=1 no DB (Bug #4)
5. Trocar nome do veículo → nome persiste após restart (Bug #3)
6. Tentar abrir "Redline Executivo" ou "Bennys Executivo" → não crasha (Bug #6)
7. Em servidor ESX → `/removeTemp <id>` funciona (Bug #7)
