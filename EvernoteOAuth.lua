
local random = math.random
local socket = require('socket')
local url = require('socket.url')
local http = require('socket.http')
local https = require('ssl.https')
local ltn12 = require('ltn12')
--local inspect = require('inspect')

--[[
-- Cookie helper functions from: https://github.com/diegonehab/luasocket/
--]]
local token_class =  '[^%c%s%(%)%<%>%@%,%;%:%\\%"%/%[%]%?%=%{%}]'

local function unquote(t, quoted)
    local n = string.match(t, "%$(%d+)$")
    if n then n = tonumber(n) end
    if quoted[n] then return quoted[n]
    else return t end
end

local function parse_set_cookie(c, quoted, cookie_table)
    c = c .. ";$last=last;"
    local _, __, n, v, i = string.find(c, "(" .. token_class ..
        "+)%s*=%s*(.-)%s*;%s*()")
    local cookie = {
        name = n,
        value = unquote(v, quoted),
        attributes = {}
    }
    while 1 do
        _, __, n, v, i = string.find(c, "(" .. token_class ..
            "+)%s*=?%s*(.-)%s*;%s*()", i)
        if not n or n == "$last" then break end
        cookie.attributes[#cookie.attributes+1] = {
            name = n,
            value = unquote(v, quoted)
        }
    end
    cookie_table[#cookie_table+1] = cookie
end

local function split_set_cookie(s, cookie_table)
    cookie_table = cookie_table or {}
    -- remove quoted strings from cookie list
    local quoted = {}
    s = string.gsub(s, '"(.-)"', function(q)
        quoted[#quoted+1] = q
        return "$" .. #quoted
    end)
    -- add sentinel
    s = s .. ",$last="
    -- split into individual cookies
    i = 1
    while 1 do
        local _, __, cookie, next_token
        _, __, cookie, i, next_token = string.find(s, "(.-)%s*%,%s*()(" ..
            token_class .. "+)%s*=", i)
        if not next_token then break end
        parse_set_cookie(cookie, quoted, cookie_table)
        if next_token == "$last" then break end
    end
    return cookie_table
end

local function quote(s)
    if string.find(s, "[ %,%;]") then return '"' .. s .. '"'
    else return s end
end

local _empty = {}
local function build_cookies(cookies)
    s = ""
    for i,v in ipairs(cookies or _empty) do
        if v.name and v.name ~= "$last" then
            s = s .. v.name
            if v.value and v.value ~= "" then
                s = s .. '=' .. quote(v.value)
            end
            s = s .. "; "
        end
    end
    return s
end

--[[
--  Gist source: https://gist.github.com/jrus/3197011
--]]
local function uuid4()
    math.randomseed(os.time())
    local template ='xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

local OAuth = {
  domain,
  username,
  password,
  code,

  urlPath = {
    oauth = "/OAuth.action?oauth_token=",
    access = "/OAuth.action",
    token = "/oauth",
    login = "/Login.action",
    tfa = "/OTCAuth.action",
  },
  postData = {
    login = {
      login = 'Sign+in',
      username = '',
      password = '',
      targetUrl = nil,
    },
    access = {
      authorize = 'Authorize',
      oauth_token = nil,
      oauth_callback = nil,
      embed = 'false',
    },
    tfa = {
      code = '',
      login = 'Sign+in',
    },
  },
  cookies = {},
  tmpOAuthToken,
  verifierToken,
  OAuthToken,
  incorrectLogin = 0,
  incorrectCode = 0,
}

function OAuth:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  if o.init then o:init() end
  return o
end

function OAuth:init()
  local config = require('EvernoteConfig')
  if self.domain then
    self.baseUrl = config["BASE_URL_"..self.domain:upper()]
    self.consumer_key = config["CONSUMER_KEY_"..self.domain:upper()]
    self.signature = config["CONSUMER_SECRET_"..self.domain:upper()]
  else
    self.baseUrl = config.BASE_URL
    self.consumer_key = config.CONSUMER_KEY
    self.signature = config.CONSUMER_SECRET
  end
end

function OAuth:getTokenQueryData(args)
  local data = {
    oauth_consumer_key = self.consumer_key,
    oauth_signature = self.signature,
    oauth_signature_method = 'PLAINTEXT',
    oauth_timestamp = tostring(os.time()),
    oauth_nonce = uuid4()
  }
  for k,v in pairs(args or {}) do
    data[k] = v
  end

  return data
end


function OAuth:loadPage(method, path, params, data)
  local request, headers, sink = {}, {}, {}

  -- Build query string
  local query = ""
  for k,v in pairs(data) do
    query = query .. k .. '=' .. v .. '&'
  end

  -- Write URL
  local parsed = url.parse(self.baseUrl)
  parsed.path = path
  parsed.params = params
  parsed.query = method == "GET" and query or nil
  parsed.protocol = "sslv23"

  -- Write headers
  headers['cookie'] = build_cookies(self.cookies)
  if method == "POST" then
    headers["content-type"] = "application/x-www-form-urlencoded"
    headers["content-length"] = string.len(query)
  end

  -- HTTP request
  request['url'] = url.build(parsed)
  request['method'] = method
  request['source'] = method == "POST" and ltn12.source.string(query) or nil
  request['sink'] = ltn12.sink.table(sink)
  request['headers'] = headers

  http.TIMEOUT, https.TIMEOUT = 10, 10
  local httpRequest = parsed.scheme == 'http' and http.request or https.request
  local code, headers, status = socket.skip(1, httpRequest(request))

  -- raise error message when page cannot be loaded
  if headers == nil and code then
    error(code)
  end

  -- Update cookies
  local cookies = split_set_cookie(headers['set-cookie'] or "")
  for lk,lv in pairs(cookies) do
    for sk,sv in pairs(self.cookies) do
      if lv.name == sv.name then
        self.cookies[sk] = lv
        cookies[lk] = nil
      end
    end
    table.insert(self.cookies, cookies[lk])
  end

  return code, headers['location'], table.concat(sink)
end

function OAuth:parseResponse(content)
  local response = {}
  for item in (content.."&"):gmatch("(.-)&") do
    local _, _, key, val = item:find("(.+)%s*=%s*(.+)")
    if key then response[key] = url.unescape(val or "") end
  end

  return response
end

function OAuth:getTmpOAuthToken()
  local code, _, content = self:loadPage(
          "GET", self.urlPath['token'], nil,
          self:getTokenQueryData({ oauth_callback = self.baseUrl }))

  if code ~= 200 then
    error("Unexpected response status to get temp oauth token", code)
  end

  local response = self:parseResponse(content)
  if not response.oauth_token then
    error("Temporary OAuth token not found")
  end

  self.tmpOAuthToken = response.oauth_token

  return self.tmpOAuthToken
end

function OAuth:getCookie(name)
  for _,v in ipairs(self.cookies) do
    if v.name == name then return v.value end
  end
end

function OAuth:handleTwoFactor()
  self.postData['tfa']['code'] = self.code or ('xxxxxx'):gsub("x", function()
          return string.char(random(97, 122)) end)
  local code, loc, content = self:loadPage("POST",
          self.urlPath['tfa'], "jsessionid="..self.jsessionid,
          self.postData['tfa'])

  if not loc and code == 200 then
    if self.incorrectLogin < 3 then
      self.incorrectLogin = self.incorrectLogin + 1
      return self:handleTwoFactor()
    else
      error("Incorrect two factor code")
    end
  end

  if not loc then
    error("Target URL was not found in the response on login")
  end

  return true
end

function OAuth:login()
  local code, _, response = self:loadPage("GET", self.urlPath['login'], nil,
          { oauth_token = self.tmpOAuthToken })

  if code ~= 200 then
    error("Unexpected response code to login", code)
  end

  self.jsessionid = self:getCookie('JSESSIONID')
  if not self.jsessionid then
    error("No JSESSIONID value in the response cookies")
  end

  local target_url = url.escape(self.urlPath['oauth'])..self.tmpOAuthToken
  self.postData['login']['username'] = self.username
  self.postData['login']['password'] = self.password
  self.postData['login']['targetUrl'] = target_url
  self.postData['login']['hpts'] = response:match('%("hpts"%)%.value.-"(.-)"')
  self.postData['login']['hptsh'] = response:match('%("hptsh"%)%.value.-"(.-)"')
  local code, loc, content = self:loadPage("POST",
          self.urlPath['login'], "jsessionid="..self.jsessionid,
          self.postData['login'])

  if not loc and code == 200 then
    if self.incorrectLogin < 3 then
      print("Sorry, incorrect username or password")
      self.incorrectLogin = self.incorrectLogin + 1
      return self:login()
    else
      error("Incorrect username or password")
    end
  end

  if not loc then
    error("Target URL was not found in the response on login")
  end

  if code == 302 then
    return self:handleTwoFactor()
  end

  return true
end

function OAuth:_getCsrfToken()
  local code, _, content = self:loadPage("GET",
          self.urlPath['access'], nil, {oauth_token = self.tmpOAuthToken})
  return content
end

function OAuth:allowAccess()
  local content = self:_getCsrfToken()
  self.postData.access.oauth_token = self.tmpOAuthToken
  self.postData.access.oauth_callback = self.baseUrl
  self.postData.access.csrfBusterToken = content:match('"csrfBusterToken" value="(.-)"')
  local code, loc, content = self:loadPage(
          "POST", self.urlPath['access'], nil, self.postData.access)

  if code ~= 302 then
    error("Unexpected response status on allowing access", code)
  end

  local location = self:parseResponse(loc)

  if not location['oauth_verifier'] then
    error("OAuth verifier not found")
  end

  self.verifierToken = location['oauth_verifier']

  return self.verifierToken
end

function OAuth:getOAuthToken()
  local code, _, content = self:loadPage("GET", self.urlPath['token'], nil,
          self:getTokenQueryData({
            oauth_token = self.tmpOAuthToken,
            oauth_verifier = self.verifierToken
          }))

  if code ~= 200 then
    error("Unexpected response status on getting oauth token", code)
  end

  local response = self:parseResponse(content)
  if not response['oauth_token'] then
    error("OAuth token not found")
  end

  self.OAuthToken = response['oauth_token']

  return self.OAuthToken
end

function OAuth:getToken()
  if self.OAuthToken then return self.OAuthToken end

  self:getTmpOAuthToken()
  self:login()
  self:allowAccess()

  return self:getOAuthToken()
end

return OAuth

