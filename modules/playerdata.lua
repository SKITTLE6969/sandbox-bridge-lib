-- QBX PlayerData compatibility for Sandbox.
-- Adds the QBX.PlayerData global and keeps it updated.

if IsDuplicityVersion() then return end

QBX = {}
QBX.PlayerData = exports['sandbox-bridge-lib']:GetPlayerData() or {}

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    QBX.PlayerData = {}
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(value)
    QBX.PlayerData = value or {}
end)
