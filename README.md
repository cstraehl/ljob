trivial Luajit multiprocessing 
==============================

Provides
--------

* proc = job.run(function, arg1, arg2, ...) - create a new process that executes function with given arguments, returns a proc object
* proc.wait()                               - waits for the spawned process to finish, returns the return values of function

The catch of the library is, it uses the fork system call.
Thus the function and its arguments can be anything and do not have to be serializable.
*Only the return values* of the function must be supported by lua-marshal :  Tables, strings, numbers etc. work
out of the box. Only ffi data types etc. must provide a `__persist` hook (see https://github.com/richardhundt/lua-marshal).

Tiny Example:                                                     
```Lua
local job = require("job")

local proc = job.run(
    function(a)
        return a .. " ok"
    end,
    "test")

local result = proc:wait()

assert(result == "test ok")
```
