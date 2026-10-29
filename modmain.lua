local _G = GLOBAL
Assets = { Asset("ANIM", "anim/winona_battery_placement.zip") }
local ToggleNightvisionKey = GetModConfigData("FREENIGHTVISION_TOGGLEKEY"):lower():byte()
_G.TheInput:AddKeyUpHandler(ToggleNightvisionKey, function()
    if not _G.TheWorld or not _G.ThePlayer or not _G.ThePlayer.components.playervision then return end
    local screen = _G.TheFrontEnd:GetActiveScreen() and _G.TheFrontEnd:GetActiveScreen().name or ""
    if screen:find("HUD") == nil then return end
    local hasnightvision = _G.ThePlayer.components.playervision:HasNightVision()
    _G.ThePlayer.components.playervision.forcenightvision = not hasnightvision
    _G.ThePlayer:PushEvent("nightvision", not hasnightvision)
    _G.ThePlayer:PushEvent("ccoverrides", nil)
    _G.ThePlayer:PushEvent("ccphasefn", nil)
end)
local function SpawnGrueAlert(parent)
    if not parent then return end
    local inst = _G.CreateEntity()
    inst.entity:SetCanSleep(false)
    inst.persists = false
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")
    inst.AnimState:SetBank("winona_battery_placement")
    inst.AnimState:SetBuild("winona_battery_placement")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetLightOverride(1)
    inst.AnimState:SetOrientation(_G.ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(_G.LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(1)
    inst.AnimState:SetScale(0, 0)
    inst.AnimState:SetAddColour(1, 0, 0, 0)
    inst.entity:SetParent(parent.entity)
    for i = 0, 8 do
        inst:DoTaskInTime(_G.FRAMES * i, function(inst) inst.AnimState:SetScale(i/8., i/8.) end)
        inst:DoTaskInTime(_G.FRAMES * (i + 9), function(inst) inst.AnimState:SetScale(1 - i/8., 1 - i/8.) end)
    end
    inst:DoTaskInTime(0.5, function(inst) inst:Remove() end)
end
AddPlayerPostInit(function(inst)
    inst:DoTaskInTime(0.25, function()
        if inst == _G.ThePlayer and inst.LightWatcher ~= nil and GetModConfigData("FREENIGHTVISION_GRUEALERT") then
            inst:DoPeriodicTask(0.25, function(inst)
                if inst.LightWatcher and inst.LightWatcher:GetTimeInDark() > 0.001 and inst.components.playervision and inst.components.playervision.forcenightvision then
                    SpawnGrueAlert(inst)
                end
            end)
        end
    end)
end)