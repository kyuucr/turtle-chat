express = require 'express'
stylus = require 'stylus'
assets = require 'connect-assets'
sip = require 'sip-websocket'

app = express.createServer()
app.use assets()
app.set 'view engine', 'jade'
app.use express.static __dirname + '/public'

app.get '/', (req, resp) -> resp.render 'test-sip', {title: 'turtle-chat'}

app.listen process.env.VMC_APP_PORT or 3000, -> console.log 'Listening...'

sip.start { websocket: app }, (request, remote) ->
  console.log 'Receiving request from ' + remote.address + ':' + remote.port + ' Protocol: ' + remote.protocol
  console.log 'Method ' + request.method
  # make 302 respond for now
  response = sip.makeResponse request, 302, 'Moved Temporarily'
  uri = sip.parseUri request.uri
  uri.host = 'backup.somewhere.net'
  response.headers.contact = [{uri: uri}]

  sip.send response