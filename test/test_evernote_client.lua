
package.path = package.path .. ";../?.lua"
package.cpath = package.cpath .. ";../thrift/lib/?.so"

local inspect = require("inspect")
local EvernoteClient = require("EvernoteClient")
local EvernoteOAuth = require("EvernoteOAuth")

local authToken = nil
local username = ""
local password = ""

describe("EvernoteClient API", function()
  it("should be created", function()
    local oauth = EvernoteOAuth:new{
      domain = "sandbox",
      username = username,
      password = password,
    }
    client = EvernoteClient:new{
      domain = "sandbox",
      authToken = authToken or oauth:getToken(),
    }
    assert.is_not_nil(client)
  end)
  it("should get user store", function()
    user_store = client:getUserStore()
    assert.is_not_nil(user_store)
  end)
  it("should get note store", function()
    note_store = client:getNoteStore()
    assert.is_not_nil(note_store)
  end)
  it("should get user info", function()
    user = client:getUserInfo()
    assert.is_not_nil(user)
  end)
  it("should list notebooks", function()
    notebooks = client:findNotebooks()
  end)
  local notebook_name = "lua's notebook"
  local notebook_new_name = "luna's notebook"
  it("should create notebook", function()
    for i=1, #notebooks do
      if notebooks[i].name == notebook_name then
        assert.truthy(client:removeNotebook(notebooks[i].guid))
      end
      if notebooks[i].name == notebook_new_name then
        assert.truthy(client:removeNotebook(notebooks[i].guid))
      end
    end
    notebook = client:createNotebook(notebook_name)
    assert.truthy(notebook.guid)
    assert.are.same(notebook.name, notebook_name)
  end)
  it("should modify notebook name", function()
    assert.truthy(client:updateNotebook(notebook.guid, notebook_new_name))
  end)
  it("should find notebook by title", function()
    local guid = client:findNotebookByTitle(notebook_new_name)
    assert.are.same(guid, notebook.guid)
    assert.are.same(client:findNotebookByTitle("non-exsitent-title"), nil)
  end)
  it("should create note", function()
    note = client:createNote("Test note title", "Test note content",
            {"test"}, notebook.guid)
    assert.truthy(note)
  end)
  it("should update note", function()
    res = client:updateNote(note.guid, "new title", "new content",
            {"test1"}, notebook.guid)
    assert.truthy(res)
  end)
  it("should find note by title", function()
    local guid = client:findNoteByTitle("new title", notebook.guid)
    assert.are.same(guid, note.guid)
    assert.are.same(client:findNoteByTitle("non-existent-title"), nil)
  end)
  it("should delete note", function()
    assert.truthy(client:removeNote(note.guid))
  end)
  it("should delete notebook", function()
    -- deleting notebook is only allowed in sandbox
    --assert.truthy(client:removeNotebook(notebook.guid))
  end)
end)

