local socket = require("socket")
local beanjob = require("beanjob")

local beanstalk = { -- Module
	default_server = "127.0.0.1";
	default_port = 11300;
}

local beanstalk_unconnected = {} -- Beanstalk object methods (when not connected)
local beanstalk_connected = {} -- Beanstalk object methods (when connected)

-- Metatables
local beanstalk_unconnected_mt = { __index = beanstalk_unconnected }
local beanstalk_connected_mt = { __index = beanstalk_connected }


setmetatable(beanstalk_unconnected, { __index = function (t, k, v)
	if beanstalk_connected[k] then
		return function ()
			return nil, "Not connected to beanstalkd"
		end
	end
end })

--Carriage-return + linefeed for writing to the socket.
local crlf = "\r\n"

--Create a new beanstalk object
function beanstalk.new() 
	local object = { watching = {} }
	setmetatable(object, beanstalk_unconnected_mt)
	return object
end

--Connect to a server + port
function beanstalk_unconnected:connect(server, port)
	server = server or beanstalk.default_server
	port = port or beanstalk.default_port
	self.connection = socket.tcp()
	local result, err = self.connection:connect(server, port)
	if result ~= nil then
		print("Successful connection to "..server..":"..port)
		setmetatable(self, beanstalk_connected_mt)
		return nil
	else
		error(err)
	end
end

--Put a job into the queue
function beanstalk_connected:put(data, priority)
	output = "put "..priority.." 1 1 "..#data
	self.connection:send(output..crlf..data..crlf)
	line = self.connection:receive( "*l")
	if starts(line,"INSERTED") then
		print(line)
		return nil
	else
		error(line)
	end	
end

--Watch a tube, for reserving jobs
function beanstalk_connected:watch(tube)
	self.connection:send("watch "..tube..crlf)
	line = self.connection:receive( "*l")
	if starts(line,"WATCHING") then
		print(line)
		return nil
	else
		error(line)
	end	
end

--Reserve a job from the queue, return a beanjob
function beanstalk_connected:reserve()
	self.connection:send("reserve"..crlf)
	line = self.connection:receive( "*l")
	print(line)
	if starts(line,"RESERVED") then
		id, data = string.match( line, "%S+ (%S+) (%S+)" )
		line = self.connection:receive("*l")
		job = beanjob:new(line, id)
		return job
	else
		error(line)
	end
end

--Use a tube, for writing jobs
function beanstalk_connected:use(tube)
	self.connection:send("use "..tube..crlf)
	line = self.connection:receive( "*l")
	if (starts(line,"USING")) then
		print(line)
		return nil
	else 
		error(line)
	end
end

--Utility function for checking whether one string starts with another
function starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

return beanstalk
