-- sandbox-bridge-lib/client/callbacks.lua
-- Loaded by client/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Callbacks
-- ---------------------------------------------------------------------------

function TriggerServerCallback(name, callback, ...)
    local args = { n = select('#', ...), ... }
    exports['sandbox-base']:ServerCallback(name, { __bridgeArgs = args }, callback)
end

