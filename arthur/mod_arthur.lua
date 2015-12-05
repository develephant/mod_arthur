--============================================================================--
--== mod_arthur
--== An oauth.io module for CoronaSDK
--== (c)2015 Chris Byerley <@develephant>
--============================================================================--
--== See https://oauth.io
--============================================================================--
local Api = require('arthur.ApiClass')

local arthur = {}

arthur.config = {}

arthur.config.app_key = nil
arthur.config.oauth_host = nil

--== Make an api connection
arthur.api = function( provider, params, callback )
  return Api:new( provider, params, arthur.config.app_key, arthur.config.oauth_host, callback )
end

--== Initialize the module
arthur.init = function( app_key, oauth_host )
  local oauth_host = oauth_host or 'https://oauth.io'
  arthur.config.app_key = app_key
  arthur.config.oauth_host = oauth_host
end

--== Alias the trace utility
arthur.trace = require('arthur.UtilsClass').trace

return arthur
