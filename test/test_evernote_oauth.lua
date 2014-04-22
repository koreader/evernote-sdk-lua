
package.path = package.path .. ";../?.lua"

local inspect = require("inspect")
local EvernoteOAuth = require("EvernoteOAuth")

local username = ""
local password = ""

describe("Evernote OAuth", function()
  it("should be created", function()
    oauth = EvernoteOAuth:new{
      domain = "sandbox",
      username = username,
      password = password,
    }
    assert.truthy(oauth)
  end)
  it("should get tmp auth token", function()
    assert.truthy(oauth:getTmpOAuthToken())
  end)
  it("should login to Evernote", function()
    assert.truthy(oauth:login())
  end)
  it("should allow access", function()
    assert.truthy(oauth:allowAccess())
  end)
  it("should get OAuth token", function()
    assert.truthy(oauth:getOAuthToken())
  end)
  it("should get token directly", function()
    assert.truthy(oauth:getToken())
  end)
end)

