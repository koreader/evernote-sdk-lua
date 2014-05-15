
require "thrift.TBinaryProtocol"
require "thrift.THttpClient"

require "evernote.userstore.UserStore"
require "evernote.notestore.NoteStore"

--local inspect = require("inspect")
local dtd = '<?xml version="1.0" encoding="UTF-8"?>' ..
            '<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">'

EvernoteClient = __TObject:new{
  __type = "EvernoteClient",
  domain,
  authToken,

  userStore,
  noteStore,
}

function EvernoteClient:getUserStore()
  if self.userStore then return self.userStore end

  local config = require('EvernoteConfig')
  if self.domain then
    self.userStoreUri = config["USER_STORE_URL_"..self.domain:upper()]
  else
    self.userStoreUri = config.USER_STORE_URL
  end
  local userStoreHttpClient = THttpClient:new{ uri = self.userStoreUri }
  local userStoreProtocol = TBinaryProtocol:new{ trans = userStoreHttpClient }
  self.userStore = UserStoreClient:new{ iprot = userStoreProtocol }
  self:checkVersion()
  return self.userStore
end

function EvernoteClient:getNoteStore()
  if self.noteStore then return self.noteStore end

  self.noteStoreUri = self:getUserStore():getNoteStoreUrl(self.authToken)
  local noteStoreHttpClient = THttpClient:new{ uri = self.noteStoreUri }
  local noteStoreProtocol = TBinaryProtocol:new{ trans = noteStoreHttpClient }
  self.noteStore = NoteStoreClient:new{ iprot = noteStoreProtocol }
  return self.noteStore
end

function EvernoteClient:checkVersion()
  local versionOK = self:getUserStore():checkVersion("Lua EMDATest",
        EDAM_VERSION_MAJOR, EDAM_VERSION_MINOR
  )
  if not versionOK then
    error("Old EDAM version")
  end
end

function EvernoteClient:getUserInfo()
  return self:getUserStore():getUser(self.authToken)
end

function EvernoteClient:findNotebooks()
  return self:getNoteStore():listNotebooks(self.authToken)
end

--[[
-- find notebook by title in all notebooks
-- return notebook guid if found, otherwise return nil
--]]
function EvernoteClient:findNotebookByTitle(title)
  local notebooks = self:findNotebooks()
  for _,notebook in ipairs(notebooks) do
    if notebook.name == title then return notebook.guid end
  end
end

function EvernoteClient:createNotebook(name)
  local notebook = Notebook:new{ name = name }
  return self:getNoteStore():createNotebook(self.authToken, notebook)
end

function EvernoteClient:updateNotebook(guid, name)
  local notebook = Notebook:new{
    name = name,
    guid = guid
  }
  return self:getNoteStore():updateNotebook(self.authToken, notebook)
end

function EvernoteClient:removeNotebook(guid)
  return self:getNoteStore():expungeNotebook(self.authToken, guid)
end

function EvernoteClient:findNotes(keywords, count, createOrder, offset)
  local noteFilter = NoteFilter:new{
    order = createOrder and NoteSortOrder.CREATED or NoteSortOrder.RELEVANCE,
    words = keywords or '',
  }
  return self:getNoteStore():findNotes(self.authToken, noteFilter, offset, count)
end

function EvernoteClient:loadNoteContent(note)
  note.content = self:getNoteStore():getNoteContent(self.authToken, note.guid)
  if note.tagGuids and not note.tagNames then
    note.tagNames = {}
    for i=1, #note.tagGuids do
      local tag = self:getNoteStore():getTag(self.authToken, note.tagGuids[i])
      table.insert(note.tagNames, tag.name)
    end
  end
end

--[[
-- find note by title in notebook
-- return note guid if found, otherwise return nil
--]]
function EvernoteClient:findNoteByTitle(title, notebook)
  local spec = NotesMetadataResultSpec:new{ includeTitle = true }
  local filter = NoteFilter:new{
    order = NoteSortOrder.UPDATED,
    notebookGuid = notebook
  }
  local index = 0
  while true do
    local metadata = self:getNoteStore():findNotesMetadata(self.authToken,
            filter, index, 20, spec)
    for _,note in ipairs(metadata.notes) do
      if note.title == title then return note.guid end
    end
    if metadata.totalNotes <= metadata.startIndex + #metadata.notes then
      break
    end
    index = index + #metadata.notes
  end
end

local function enmlify(content)
  return dtd..'<en-note>'..content..'</en-note>'
end

local function hextobin(s)
	return (s:gsub('(%x%x)', function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

local function createImageResources(resources)
  local res = {}
  for _, resource in ipairs(resources or {}) do
    local image = resource.image
    if image then
      local data = Data:new{
        size = #image.png,
        bodyhash = hextobin(image.hash),
        body = image.png
      }
      local resource = Resource:new{
        mime = "image/png",
        data = data
      }
      table.insert(res, resource)
    end
  end
  return res
end

function EvernoteClient:createNote(title, content, resources, tags, notebook, created)
  local note = Note:new{
    title = title,
    content = enmlify(content),
    resources = createImageResources(resources),
    created = created,
    tagNames = tags,
    notebookGuid = notebook,
  }
  return self:getNoteStore():createNote(self.authToken, note)
end

function EvernoteClient:updateNote(guid, title, content, resources, tags, notebook)
  local note = Note:new{
    guid = guid,
    title = title,
    content = enmlify(content),
    resources = createImageResources(resources),
    tagNames = tags,
    notebookGuid = notebook,
  }
  return self:getNoteStore():updateNote(self.authToken, note)
end

function EvernoteClient:removeNote(guid)
  self:getNoteStore():deleteNote(self.authToken, guid)
  return true
end

function EvernoteClient:findTags()
  return self:getNoteStore():listTags(self.authToken)
end

function EvernoteClient:createTag(name)
  local tag = Tag:new{ name = name }
  return self:getNoteStore():createTag(self.authToken, tag)
end

function EvernoteClient:updateTag(guid, name)
  local tag = Tag:new{
    name = name,
    guid = guid
  }
  return self:getNoteStore():updateTag(self.authToken, tag)
end

function EvernoteClient:removeTag(guid)
  return self:getNoteStore():expungeTag(self.authToken, guid)
end

return EvernoteClient

