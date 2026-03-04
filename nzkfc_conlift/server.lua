RegisterNetEvent('nzkfc_conlift:requestMove', function(targetLevel)
    local src = source
    TriggerClientEvent('nzkfc_conlift:approvedMove', -1, targetLevel)
end)

RegisterNetEvent('nzkfc_conlift:syncRequest', function()
end)
