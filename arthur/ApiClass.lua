--============================================================================--
--== mod_arthur - api
--== An oauth.io module for CoronaSDK
--== (c)2015 Chris Byerley <@develephant>
--============================================================================--
local Class = require('arthur.30log')
local Utils = require('arthur.UtilsClass')

--== Create an API class with 30Log
local Api = Class('Api')
function Api:init( provider, params, app_key, oauth_host, callback )
  --== Store callback and parameters
  self._callback = callback
  self.params = params

  --== Local cache
  self.local_cache = nil

  --== Set up config
  self:_initApiConfig()
  self.config.provider = provider or nil
  self.config.oauth_host = oauth_host or ''
  self.config.app_key = app_key or nil
  --== WebView for client auth
  self.webView = nil
  --== Check if client needs token
  self:_doApiAuthCheck()
end

--== Set the api path prefix
function Api:setPrefix( prefix )
  self.config.api_prefix = prefix or nil
end

--== Check if token is expired
function Api:isTokenExpired()
  if self.config.expiry then
    if os.time() >= self.config.expiry then
      return true
    end
  else
    return true
  end
  return false
end

--== Get the token expiration time
function Api:getTokenExpiry()
  if self.config.expiry then
    return self.config.expiry
  end
  return 0
end
--===========================================================================--
--== API Calls
--===========================================================================--

--== Make a 'GET' call to the selected api
function Api:get( uri, params, callback )
  local opts =
  {
    uri = uri,
    method = 'GET',
    params = params,
    _callback = callback
  }

  return self:_apiRequest( opts )
end

--== Make a 'POST' call to the selected api
function Api:post( uri, params, body, callback )
  local opts =
  {
    uri = uri,
    method = 'POST',
    params = params,
    body = body,
    _callback = callback
  }

  return self:_apiRequest( opts )
end

--== Make a 'PUT' call to the selected api
function Api:put( uri, params, body, callback )
  local opts =
  {
    uri = uri,
    method = 'PUT',
    params = params,
    body = body,
    _callback = callback
  }

  return self:_apiRequest( opts )
end

--== Make a 'DELETE' call to the selected api
function Api:delete( uri, params, callback )
  local opts =
  {
    uri = uri,
    method = 'DELETE',
    params = params,
    _callback = callback
  }

  return self:_apiRequest( opts )
end

--===========================================================================--
--== Internals
--===========================================================================--

--== Generates oauth.io authorization endpoint
function Api:getAuthEndpoint()
  return self.config.oauth_host .. self.config.auth_endpoint
end

--== Generates oauth.io request endpoint
function Api:getRequestEndpoint()
  return self.config.oauth_host .. self.config.request_endpoint
end

--== Generates oauth.io -> api authorization endpoint
function Api:getProviderAuthEndpoint()
  local auth_url = string.format( self.config.auth_url_tpl,
    self:getAuthEndpoint(),
    self.config.provider,
    self.config.app_key,
    Utils.encode( self.config.oauth_host ),
    Utils.encode( self.config.redirect_uri )
  )
  return auth_url
end

--== Generates oauth.io -> api request endpoint
function Api:getProviderRequestEndpoint()
  local req_url = self:getRequestEndpoint() .. '/' .. self.config.provider
  if self.config.api_prefix then
    req_url = req_url .. '/' .. self.config.api_prefix
  end
  return req_url
end

--== Generates OAuth headers based on version
function Api:getOAuthHeader()
  if self.config.oauth_ver == 1 then
    return string.format( self.config.oauth1_header_tpl,
      self.config.app_key,
      self.config.oauth_token,
      self.config.oauth_token_secret
      )
  elseif self.config.oauth_ver == 2 then
    return string.format( self.config.oauth2_header_tpl,
      self.config.app_key,
      self.config.access_token
      )
  end
end

--== Returns the current token(s)
function Api:getOAuthTokens()
  if self.config.oauth_ver == 1 then
    return
    {
      oauth_token = self.config.oauth_token,
      oauth_token_secret = self.config.oauth_token_secret,
      oauth = 1
    }
  elseif self.config.oauth_ver == 2 then
    return
    {
      access_token = self.config.access_token,
      oauth = 2
    }
  end
end
--===========================================================================--
--== Privates
--===========================================================================--

--== All value encoding must be done
--== before sending it to request
function Api:_apiRequest( opts )
  local opts = opts
  local _callback = opts._callback

  local params = {}

  --== Expand url endpoint
  opts.uri = self:getProviderRequestEndpoint() .. opts.uri

  --== Build any query string params
  local query_str
  if opts.params and type( opts.params ) == 'table' then
    local parms = {}
    for name, value in pairs( opts.params ) do
      table.insert( parms, ( name..'='..value ) )
    end

    if #parms > 0 then
      query_str = '?' .. table.concat( parms, '&' )
      if query_str then
        opts.uri = opts.uri .. query_str
      end
    end
  end

  --== Body check
  if opts.body then
    params.body = opts.body
    params.bodyType = 'text'
  end

  --== Add oauth header, as required by api
  params.headers =
  {
    ['oauthio'] = self:getOAuthHeader()
  }

  --== Make request, and return request id
  local function _onRequest( event )

    if event.isError then
      _callback( false, "A network error occurred" )
    end

    if event.phase == 'ended' then
      if event.responseType == 'text' then
        --== try json convert
        if event.response then
          local status, content_tbl = pcall( Utils.json2tbl, event.response )
          if status then
            _callback( content_tbl, event.status, event.url )
          else
            _callback( false, "Data could not be converted" )
          end
        end
      end
    end
  end

  return network.request( opts.uri, opts.method, _onRequest, params )
end

--== Check if we have a token
function Api:_doApiAuthCheck()
  --== Check if token expired
  if self:isTokenExpired() then
    --== Token has expired
    self.local_cache = nil
    self:_popForAuth()
  end
  
end

--== Open WebView and collect token
function Api:_popForAuth()
  --== Get api authorization endpoint
  local auth_url = self:getProviderAuthEndpoint()

  --== Create WebView, send request, and add listener
  self.webView = native.newWebView( Utils.getPortalSize() )
  self.webView:request( auth_url )
  self.webView:addEventListener( 'urlRequest', function( event )

    --== Check for oauthio results
    if event.url:find('#oauthio') then
      --== Parse the oauthio return url
      local purl = Utils.parse( event.url )
      --== Mobile app needs to check for `localhost`
      if purl.host == 'localhost' then
        --== Pull the oauthio return url parameters
        local json_res = Utils.decode( purl.fragment:sub( 9 ) )
        --== Convert result to a table
        local auth = Utils.json2tbl( json_res )
        
        --== Check for success
        if auth.status == 'success' then
          --== Clean up WebView
          self.webView:removeSelf()
          self.webView = nil

          --== Calc OAuth version depending on key type
          if auth.data.access_token then
            --== access_token indicates OAuth V2
            self.config.oauth_ver = 2
            --== Store access_token
            self.config.access_token = auth.data.access_token
            -- Calc the token expiration
            if auth.data.expires_in then
              self.config.expiry = os.time() + auth.data.expires_in
            end
          elseif auth.data.oauth_token and auth.data.oauth_token_secret then
            --== oauth_token + oauth_token_secret indicates OAuth V1
            self.config.oauth_ver = 1
            --== Store OAuth token and secret
            self.config.oauth_token = auth.data.oauth_token
            self.config.oauth_token_secret = auth.data.oauth_token_secret
            -- V1 tokens have no expiration
            self.config.expiry = nil
          end
          
          --== local cache
          self.local_cache = self:getOAuthTokens()
          
          --== Run the callback, with success true
          self._callback( true )

        elseif auth.status == 'error' then --== Error status
          --== Print out error info
          print('err', auth.status, auth.message)
          --== Run the callback, with success false and err info
          self._callback( false, auth.status, auth.message )
        end

      end
    end
  end)
end

--== Set up module configuration
function Api:_initApiConfig()
  self.config =
  {
    --== V2 oauth
    access_token = nil,
    --== An optional api prefix, exp: '/v1'
    api_prefix = nil,
    --== OAuthd Public app key
    app_key = nil,
    --== server `auth` endpoint
    auth_endpoint = '/auth',
    --== provider Auth url template
    auth_url_tpl = "%s/%s?k=%s&d=%s&redirect_uri=%s",
    --== Token expiry compare with os.time (V2 only)
    expiry = nil,
    --== oauth main server / host
    oauth_host = '',
    --== V1 oauth
    oauth_token = nil,
    oauth_token_secret = nil,
    --== OAuth version
    oauth_ver = 0,
    --==header['oauthio'] v1 tpl - api request
    oauth1_header_tpl = "k=%s&oauth_token=%s&oauth_token_secret=%s",
    --==header['oauthio'] v2 tpl - api request
    oauth2_header_tpl = "k=%s&access_token=%s",
    --== The `service` provider, ex: imgur
    provider = nil,
    --== localhost redirect
    redirect_uri = 'http://localhost',
    --== server `request` endpoint
    request_endpoint = '/request'
  }
end

return Api
