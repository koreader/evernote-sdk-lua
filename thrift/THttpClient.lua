---- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements. See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership. The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License. You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing,
-- software distributed under the License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
-- KIND, either express or implied. See the License for the
-- specific language governing permissions and limitations
-- under the License.
--

require 'thrift.TTransport'

local socket = require('socket')
local url = require("socket.url")
local http = require('socket.http')
local https = require('ssl.https')
local ltn12 = require("ltn12")
--local inspect = require('inspect')

-- THttpBase
THttpBase = TTransportBase:new{
  __type = 'THttpBase',
  timeout = 1000,
  handle = nil,
}

function THttpBase:close()
  if self.handle then
    self.handle:close()
    self.handle = nil
  end
end

function THttpBase:setTimeout(timeout)
  if timeout and ttype(timeout) == 'number' then
    self.timeout = timeout
  end
end

-- THttpClient
THttpClient = THttpBase:new{
  __type = 'THttpClient',
  uri = nil,
  --offset = 1,
  ssl_params = {
    mode = 'client',
    protocol = 'sslv23',
    verify = 'peer',
    options = 'all',
  },
  buffer = '',
}

function THttpClient:isOpen()
  return self.handle and true or false
end

function THttpClient:open()
  if self.handle then
    self:close()
  end

  self.parsed = url.parse(self.uri)
  http.TIMEOUT = self.timeout
  -- Create local handle
  local conn = socket.tcp()
  conn:connect(self.parsed.host, self.parsed.port)
  if self.parsed.scheme == 'https' then
    conn = ssl.wrap(conn, self.ssl_params)
    conn:dohandshake()
  end

  self.handle = conn

end

function THttpClient:read(len)
  local content = table.concat(self.sink)
  local buf = string.sub(content, self.offset, self.offset + len - 1)
  if not buf or string.len(buf) ~= len then
    terror(TTransportException:new{errorCode = TTransportException.UNKNOWN})
  end
  self.offset = self.offset + len
  return buf
end

function THttpClient:write(buf)
  self.buffer = self.buffer .. buf
end

function THttpClient:flush()
  if self:isOpen() then
    self:close()
  end

  self.request = {}
  self.headers = {}

  self.request.sink, self.sink = ltn12.sink.table()
  self.offset = 1

  -- Pull data out of buffer
  local data = self.buffer
  self.buffer = ''

  -- Write headers
  self.headers['content-type'] = 'application/x-thrift'
  self.headers['content-length'] = string.len(data)

  -- HTTP request
  self.request['url'] = self.uri
  self.request['method'] = 'POST'
  self.request['source'] = ltn12.source.string(data)
  self.request['headers'] = self.headers

  local parsed = url.parse(self.uri)
  if parsed.scheme == 'http' then
    self.code, self.headers, self.status = socket.skip(1, http.request(self.request))
  else
    self.code, self.headers, self.status = socket.skip(1, https.request(self.request))
  end

  -- raise error message when network is unavailable
  if self.headers == nil then
    terror(TTransportException:new{errorCode = TTransportException.NOT_OPEN})
  end

  --print('sink', inspect(self.sink))
  --print('code:', self.code)
  --print('headers:', inspect(self.headers))
  --print('status:', self.status)
end

