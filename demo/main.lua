--============================================================================--
--== mod_arthur tumblr demo
--== An oauth.io module for CoronaSDK
--== (c)2015 Chris Byerley <@develephant>
--============================================================================--

--== tumblr oauth.io test
--== https://oauth.io
--== https://www.tumblr.com/docs/en/api/v2

--============================================================================--
--== For the demo make sure to copy a current version of the `arthur` mod
--== folder into this demo directory before running the example. You will
--== also need to be signed up with oauth.io, have an oauth.io `app` set-up
--== with `tumblr` added as an oauth data provider.
--============================================================================--
local Arthur = require("arthur.mod_arthur")
--============================================================================--
--== Initialize with your public `app` key from oauth.io
Arthur.init( '<oauthio_public_application_key>' )
--== Forward reference
local tumblr_api
--== Demo function
local function _startTumbler()
  --== onReady callback
  local function _onTumblrReady( ready )
    if ready then
      --== Set the api prefix
      tumblr_api:setPrefix('v2')
      
      --== Store the blog url we want to query
      local blog_url = 'good.tumblr.com'
      
      --== Make a call to the tumblr api via oauth.io
      --== https://www.tumblr.com/docs/en/api/v2#blog-info
      tumblr_api:get('/blog/'..blog_url..'/info', nil, function( content )
        --== Output the results
          print('==> tumblr', blog_url..' [info]')
        Arthur.trace( content )
        
        --== Make a second call, with parameters
        --== https://www.tumblr.com/docs/en/api/v2#blog-likes
        tumblr_api:get('/blog/'..blog_url..'/likes', { limit = 2 }, function( content )
          --== Output the results
          print('==> tumblr', blog_url..' [likes]')
          Arthur.trace( content )
        end)
      end)

    end
  end
  
  --== Create new API object for `tumblr`, with ready callback
  tumblr_api = Arthur.api('tumblr', nil, _onTumblrReady )

end

--== Run demo
_startTumbler()
