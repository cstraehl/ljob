require("luarocks.loader")
local ljob = require("ljob")

-- test result and argument handling
local proc = ljob.run(
    function(a)
        return a .. " ok"
    end,
    "test")
local result = proc:wait()
assert(result == "test ok")

-- test error handling
local proc = ljob.run(
    function()
        assert(1 == 2)
    end)
ok, err = pcall(function() proc:wait() end)
assert(ok == false)

-- test queue
local queue = ljob.queue()
for i = 1, 100,1 do
    queue:add( function(a) return a end, i)
end
local results = queue:run(2)
for i = 1, 100,1 do
    assert(results[i][1] == i)
end

local ljob = require("ljob")

local queue = ljob.queue()

for i = 1, 10 do
    queue:add( function(x) return x end, i)
end

local results = queue:run(4)

for i, result in ipairs(results) do
    print("Result of job", i, " : ", unpack(result))
end

