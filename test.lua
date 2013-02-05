require("luarocks.loader")
local job = require("job")

local proc = job.run(
    function(a)
        return a .. " ok"
    end,
    "test")

local result = proc:wait()

assert(result == "test ok")
