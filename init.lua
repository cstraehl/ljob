local ffi = require("ffi")
local marshal = require("ljob.marshal")
local os = require("os")
local bit = require("bit")

ffi.cdef[[
  int fork();
  int getpid();
  int pipe(int fileds[2]);
  int read(int fd, void *buf, size_t count); 
  int write(int fd, const void *buf, size_t count); 
  int close(int fd);

  struct ljob_pollfd {
    int   fd;         /* file descriptor */
    short events;     /* requested events */
    short revents;    /* returned events */
  } ljob_pollfd;

  int poll(struct ljob_pollfd *fds, int nfds, int timeout);
]]


local ClientProcess = {}
ClientProcess.__index = ClientProcess

ClientProcess.create = function(pid)
    local self = {}
    setmetatable(self, ClientProcess)

    self.pid = pid
    self.fds = ffi.new("int[2]")
    assert(ffi.C.pipe(self.fds) ~= -1, "ljob: could not create ipc pipe!")
    self._readfd = self.fds[0]
    self._writefd = self.fds[1]
    return self
end

ClientProcess.wait = function(self)
    local msg = self:_read_pipe()
    local result = marshal.decode(msg)
    if result[1] then
        return unpack(result[2])
    else
        error(result[2])
    end
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
        if count > 0 then
            msg = msg .. ffi.string(buf, count)
        end
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
        local result
        local args = {...}
        local ok, err = pcall(function() result = { func(unpack(args)) } end)
        if ok then
            proc:_write_pipe(marshal.encode({ true, result }))
        else
            proc:_write_pipe(marshal.encode({ false, err }))
        end
        ffi.C.close(proc._writefd)
        -- terminate forked process
        os.exit()
    else
        ffi.C.close(proc._writefd)
    end
    return proc
end



local Queue = {}
Queue.__index = Queue

Queue.create = function()
    local p = {}
    setmetatable(p, Queue)
    p.jobs = {}
    return p
end


Queue.add = function(self, func, ...)
    table.insert(self.jobs, {func = func, args = {...}})
    return #self.jobs
end

Queue.get_result = function(self, job_nr)
    assert(self.results, "ljob: queue did not run yet!")
    return unpack(self.results[job_nr])
end

Queue.run = function(self, max_jobs)
    local max_jobs = max_jobs or 4
    local fds = ffi.new("struct ljob_pollfd[?]", max_jobs)
    local running_jobs = {}
    local results = {}

    local n_finished = 0
    while #self.jobs > 0 or #running_jobs > 0 do
        while #running_jobs < max_jobs and #self.jobs > 0 do
            local job_nr = #self.jobs
            local job = table.remove(self.jobs)
            local func = job.func
            local args = job.args
            local proc = module.run(func, unpack(args))
            table.insert(running_jobs, {proc = proc, job_nr = job_nr, job = job})
        end

        -- setup fds struct
        for i = 1, #running_jobs,1  do
            fds[i-1].fd = running_jobs[i].proc._readfd
            fds[i-1].events = 0x0001 -- set POLLIN
            fds[i-1].revents = 0x0 
        end

        local ready = ffi.C.poll(fds, #running_jobs, -1)

        if ready > 0 then
            for i = #running_jobs,1,-1 do
                -- test wether POLLIN is set
                if bit.band(fds[i-1].revents, 0x0001) > 0 then
                    -- wait for job and store results
                    local result = {running_jobs[i].proc:wait()}
                    results[running_jobs[i].job_nr] = result
                    table.remove(running_jobs, i)
                elseif bit.band(fds[i-1].revents, 0x0010) > 0 then
                    assert(1 == 2, "joblib: received SIGHUP, subprocess died")
                elseif fds[i-1].revents > 0 then
                    io.write("?", fds[i-1].revents)
                    io.flush()
                end
            end
        else
            print("ljob poll error:", ready)
        end
    end
    self.results = results

    return results
end

--- non-parallel execution of jobs
--
-- for debugging purposes
Queue.run_sync = function(self)
    local results = {}
    for i, job in ipairs(self.jobs) do
        results[i] = { job.func(unpack(job.args)) }
    end
    return results
end


module.queue = function()
    return Queue.create()
end

return module
