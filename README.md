ljob: Luajit posix based multiprocessing library
================================================

Provides
--------

* proc = ljob.run(function, arg1, arg2, ...) - create a new process that executes function with given arguments, returns a proc object
* proc:wait()                                - waits for the spawned process to finish, returns the return values of function
* queue = ljob.queue()                       - creates a queue of jobs
* queue:add(function, arg1, arg2, ...)       - adds a job to the queue
* results = queue:run(4)                     - processes all jobs in the queue using 4 workers and returns a table of the job results

Description
-----------

The catch of the library is, it uses the fork system call.
Thus the function and its arguments can be anything (including luajit ffi cdata) and do not have to be serializable.
*Only the return values* of the function must be supported by lua-marshal :  Tables, strings, numbers etc. work
out of the box. Luajit ffi data types etc. must provide a `__persist` hook (see https://github.com/richardhundt/lua-marshal).

Usage Examples
--------------

Parallel Process Example:                                                     
```Lua
local ljob = require("ljob")

-- the created process is immediately executed in parallel 
local proc = ljob.run(
    function(a)
        return a .. " ok"
    end,
    "test")

local result = proc:wait()

assert(result == "test ok")
```

Processing Queue Example:
```Lua
local ljob = require("ljob")

-- create a parallel processing queue
local queue = ljob.queue()

-- add 10 jobs to the queue
for i = 1, 10 do
    queue:add( function(x) return x end, i)
end

-- run all jobs in the queue using 4 parallel workers
local results = queue:run(4)

for i, result in ipairs(results) do
    print("Result of job", i, " : ", unpack(result))
end

```
