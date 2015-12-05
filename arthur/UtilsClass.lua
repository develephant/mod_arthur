--============================================================================--
--== mod_arthur - utilities
--== An oauth.io module for CoronaSDK
--== (c)2015 Chris Byerley <@develephant>
--============================================================================--

local url_tools = require('socket.url')
local crypto = require('crypto')
local json = require('json')

local Class = require('arthur.30log')
local Utils = Class('Utils')

function Utils:init()
  return false
end

--== Display
Utils.cx = display.contentCenterX
Utils.cy = display.contentCenterY
Utils.cw = display.viewableContentWidth
Utils.ch = display.viewableContentHeight
--== URL encoding
Utils.encode  = url_tools.escape
Utils.decode  = url_tools.unescape
Utils.parse   = url_tools.parse
--== JSON
Utils.tbl2json = json.encode
Utils.json2tbl = json.decode
--== SHA1
Utils.get_hash = function( trim )
  local sha = crypto.digest( crypto.sha1, ( tostring( os.time() )..'coronasdkrocks') )
  if trim then
    sha = string.sub( sha, 1, trim )
  end
  return sha
end

--== Display Area
Utils.getPortalSize = function()
  return display.contentCenterX, display.contentCenterY, display.viewableContentWidth, display.viewableContentHeight
end

--== Print contents of a table, with keys sorted.
local function printTable( t, indent )
  local names = {}
  if not indent then indent = "" end
  for n,g in pairs(t) do
      table.insert(names,n)
  end
  table.sort(names)
  for i,n in pairs(names) do
      local v = t[n]
      if type(v) == "table" then
          if(v==t) then -- prevent endless loop if table contains reference to itself
              print(indent..tostring(n)..": <-")
          else
              print(indent..tostring(n)..":")
              printTable(v,indent.."   ")
          end
      else
          if type(v) == "function" then
              print(indent..tostring(n).."()")
          else
              print(indent..tostring(n)..": "..tostring(v))
          end
      end
  end
end

--== Alias to 'trace'
Utils.trace = printTable

return Utils
