local ffi = require("ffi")
local marshal = require("job.marshal")
local os = require("os")

ffi.cdef[[
  int fork();
  int getpid();
  int pipe(int fileds[2]);
  int read(int fd, void *buf, size_t count); 
  int write(int fd, const void *buf, size_t count); 
  int close(int fd);
]]


local ClientProcess = {}
ClientProcess.__index = ClientProcess

ClientProcess.create = function(pid)
    local self = {}
    setmetatable(self, ClientProcess)

    self.pid = pid
    local fds = ffi.new("int[?]",2)
    assert(ffi.C.pipe(fds) ~= -1, "ljob: could not create ipc pipe!")
    self._readfd = fds[0]
    self._writefd = fds[1]
    return self
end

ClientProcess.wait = function(self)
    local msg = self:_read_pipe()
    return unpack(marshal.decode(msg))
end

ClientProcess._write_pipe = function(self,msg) 
    ffi.C.write(self._writefd, msg, #msg)
end

ClientProcess._read_pipe = function(self)
    local msg = ""
    local buf = ffi.new("char[?]", 4096)
    local count
    repeat 
        count = ffi.C.read(self._readfd, buf, 4096)
        msg = msg .. ffi.string(buf, count)
    until count == 0
    ffi.C.close(self._readfd)
    return msg
end


local module = {}
module.run = function(func, ...)
    local proc = ClientProcess.create()
    local master_pid = ffi.C.getpid()
    local job_pid = ffi.C.fork()
    local pid = ffi.C.getpid()

    if pid ~= master_pid then
        ffi.C.close(proc._readfd)
        local result = { func(...) }
        proc:_write_pipe(marshal.encode(result))
        ffi.C.close(proc._writefd)
        -- terminate forked process
        os.exit()
    else
        ffi.C.close(proc._writefd)
    end
    return proc
end


local proc = module.run(function(a) return a .. " OK" end, "test")
print(proc:wait())


return module
