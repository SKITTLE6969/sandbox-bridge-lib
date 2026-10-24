-- sandbox-bridge-lib/server/money.lua
-- Loaded by server/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Money
-- ---------------------------------------------------------------------------

function SB.GetCash(src)
    if not src or not Started('ox_inventory') then return 0 end
    local count = SafeCall(function()
        return exports.ox_inventory:GetItemCount(src, 'money')
    end)
    return tonumber(count) or 0
end

function SB.GetBank(src, refresh)
    local account = GetBankAccount(src, refresh)
    return account and (tonumber(account.Balance) or 0) or 0
end

function SB.GetMoney(src, account)
    account = Util.NormalizeAccount(account)
    if account == 'cash' then return SB.GetCash(src) end
    if account == 'bank' then return SB.GetBank(src) end
    return 0
end

function TriggerMoneyChange(src, account, amount, operation, reason)
    TriggerEvent('QBCore:Server:OnMoneyChange', src, account, amount, operation, reason)
    TriggerClientEvent('QBCore:Client:OnMoneyChange', src, account, amount, operation, reason)
end

function SB.AddMoney(src, account, amount, reason)
    account = Util.NormalizeAccount(account)
    amount = tonumber(amount) or 0
    if not src or amount <= 0 then return false end

    if account == 'cash' then
        local result = SafeCall(function()
            if not Started('Renewed-Banking') then return nil end
            return exports['Renewed-Banking']:WalletModify(src, amount, true)
        end)
        if result ~= nil and result ~= false then
            TriggerMoneyChange(src, 'cash', amount, 'add', reason)
            return true
        elseif result == nil then
            if Config and Config.Debug then
                Debug('Renewed-Banking not available for cash operations')
            end
            return false
        else
            return false
        end
    end

    if account == 'bank' then
        local stateId = GetStateId(src)
        if not stateId then
            if Config and Config.Debug then Debug('AddMoney: no stateId for bank operation') end
            return false
        end

        local bankAccount = GetBankAccount(src, true)
        if not bankAccount then
            if Started('Renewed-Banking') and exports['Renewed-Banking'].AccountsCreatePersonal then
                bankAccount = SafeCall(function()
                    return exports['Renewed-Banking']:AccountsCreatePersonal(stateId)
                end)
                if bankAccount and Config and Config.Debug then
                    Debug(('Auto-created bank account for %s'):format(tostring(stateId)))
                end
            else
                -- Try via core's EnsureBankAccount
                if EnsureBankAccount then
                    bankAccount = EnsureBankAccount(src)
                end
            end
        end
        if not bankAccount then
            if Config and Config.Debug then Debug('AddMoney: failed to get/create bank account') end
            return false
        end

        local title = reason or 'Bridge Deposit'
        local ok = SafeCall(function()
            if not Started('Renewed-Banking') then return nil end
            if exports['Renewed-Banking'].BalanceDeposit then
                return exports['Renewed-Banking']:BalanceDeposit(bankAccount.Account or bankAccount.account, amount, {
                    type = 'deposit',
                    title = title,
                    description = title,
                })
            elseif exports['Renewed-Banking'].AccountsUpdateBalance then
                return exports['Renewed-Banking']:AccountsUpdateBalance(stateId, amount, title)
            end
            return nil
        end)

        if ok then
            bankAccount.Balance = (tonumber(bankAccount.Balance or bankAccount.balance) or 0) + amount
            StoreBankAccount(src, bankAccount)
            TriggerMoneyChange(src, 'bank', amount, 'add', reason)
            return true
        elseif ok == nil then
            if Config and Config.Debug then Debug('Renewed-Banking API mismatch or unavailable') end
            return false
        else
            return false
        end
    end

    return false
end

function SB.RemoveMoney(src, account, amount, reason)
    account = Util.NormalizeAccount(account)
    amount = tonumber(amount) or 0
    if not src or amount <= 0 then return false end

    if account == 'cash' then
        local result = SafeCall(function()
            if not Started('Renewed-Banking') then return nil end
            return exports['Renewed-Banking']:WalletModify(src, -amount, true)
        end)
        if result ~= nil and result ~= false then
            TriggerMoneyChange(src, 'cash', amount, 'remove', reason)
            return true
        elseif result == nil then
            if Config and Config.Debug then Debug('Renewed-Banking not available for cash operations') end
            return false
        else
            return false
        end
    end

    if account == 'bank' then
        local stateId = GetStateId(src)
        if not stateId then return false end
        local bankAccount = GetBankAccount(src, true)
        if not bankAccount then
            if EnsureBankAccount then
                bankAccount = EnsureBankAccount(src)
            end
        end
        if not bankAccount then
            if Config and Config.Debug then Debug('RemoveMoney: failed to get bank account') end
            return false
        end

        local currentBalance = tonumber(bankAccount.Balance or bankAccount.balance) or 0
        if currentBalance < amount then
            return false
        end

        local title = reason or 'Bridge Withdrawal'
        local ok = SafeCall(function()
            if not Started('Renewed-Banking') then return nil end
            if exports['Renewed-Banking'].BalanceCharge then
                return exports['Renewed-Banking']:BalanceCharge(bankAccount.Account or bankAccount.account, amount, {
                    type = 'withdraw',
                    title = title,
                    description = title,
                })
            elseif exports['Renewed-Banking'].AccountsUpdateBalance then
                return exports['Renewed-Banking']:AccountsUpdateBalance(stateId, -amount, title)
            end
            return nil
        end)

        if ok then
            bankAccount.Balance = math.max(0, currentBalance - amount)
            if bankAccount.balance then bankAccount.balance = bankAccount.Balance end
            StoreBankAccount(src, bankAccount)
            TriggerMoneyChange(src, 'bank', amount, 'remove', reason)
            return true
        elseif ok == nil then
            if Config and Config.Debug then Debug('Renewed-Banking API mismatch or unavailable') end
            return false
        else
            return false
        end
    end

    return false
end

function SB.SetMoney(src, account, amount, reason)
    account = Util.NormalizeAccount(account)
    local target = math.max(0, tonumber(amount) or 0)
    local current = SB.GetMoney(src, account)
    if target == current then return true end

    if account == 'cash' then
        local delta = target - current
        local result = SafeCall(function()
            if not Started('Renewed-Banking') then return nil end
            return exports['Renewed-Banking']:WalletModify(src, delta, true)
        end)
        if result ~= nil and result ~= false then
            TriggerMoneyChange(src, 'cash', target, 'set', reason)
            return true
        elseif result == nil then
            if Config and Config.Debug then Debug('Renewed-Banking not available for cash operations') end
            return false
        else
            return false
        end
    end

    if account == 'bank' then
        local stateId = GetStateId(src)
        if not stateId then return false end
        local bankAccount = GetBankAccount(src, true)
        if not bankAccount then
            if Started('Renewed-Banking') and exports['Renewed-Banking'].AccountsCreatePersonal then
                bankAccount = SafeCall(function()
                    return exports['Renewed-Banking']:AccountsCreatePersonal(stateId)
                end)
            end
            if not bankAccount and EnsureBankAccount then
                bankAccount = EnsureBankAccount(src)
            end
        end
        if not bankAccount then return false end

        local delta = target - current
        local ok
        local accId = bankAccount.Account or bankAccount.account
        if delta > 0 then
            ok = SafeCall(function()
                if not Started('Renewed-Banking') then return nil end
                if exports['Renewed-Banking'].BalanceDeposit then
                    return exports['Renewed-Banking']:BalanceDeposit(accId, delta, {
                        type = 'deposit',
                        title = reason or 'Bridge Set Balance',
                        description = reason or 'Bridge Set Balance',
                    })
                elseif exports['Renewed-Banking'].AccountsUpdateBalance then
                    return exports['Renewed-Banking']:AccountsUpdateBalance(stateId, delta, reason or 'Bridge Set Balance')
                end
                return nil
            end)
        else
            ok = SafeCall(function()
                if not Started('Renewed-Banking') then return nil end
                if exports['Renewed-Banking'].BalanceCharge then
                    return exports['Renewed-Banking']:BalanceCharge(accId, math.abs(delta), {
                        type = 'withdraw',
                        title = reason or 'Bridge Set Balance',
                        description = reason or 'Bridge Set Balance',
                    })
                elseif exports['Renewed-Banking'].AccountsUpdateBalance then
                    return exports['Renewed-Banking']:AccountsUpdateBalance(stateId, delta, reason or 'Bridge Set Balance')
                end
                return nil
            end)
        end

        if ok then
            bankAccount.Balance = target
            if bankAccount.balance then bankAccount.balance = target end
            StoreBankAccount(src, bankAccount)
            TriggerMoneyChange(src, 'bank', target, 'set', reason)
            return true
        elseif ok == nil then
            if Config and Config.Debug then Debug('Renewed-Banking API mismatch or unavailable') end
            return false
        else
            return false
        end
    end

    return false
end

