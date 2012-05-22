util = require 'util'
os = require 'os'
express = require 'express'
stylus = require 'stylus'
assets = require 'connect-assets'
sip = require 'sip-websocket'
digest = require 'sip-websocket/digest'

registry = {
  '100': {password: '1234'},
  '101':  {password:  'qwerty'}
}

realm = os.hostname()

app = express.createServer()
app.use assets()
app.set 'view engine', 'jade'
app.use express.static __dirname + '/public'

app.get '/', (req, resp) -> resp.render 'test-sip', {title: 'turtle-chat'}

app.listen process.env.VMC_APP_PORT or 3000, -> console.log 'Listening on port %d ...', app.address().port

sip.start { websocket: app }, (request, remote) ->
  console.log 'Receiving request from ' + remote.address + ':' + remote.port + ' Protocol: ' + remote.protocol
  console.log 'Method ' + request.method

  if request.method == 'REGISTER'
    username = sip.parseUri(request.headers.to.uri).user
    userinfo = registry[username]
    contact = request.headers.contact
    
    if !userinfo
      rs = sip.makeResponse request, 404, 'Not found'
      sip.send rs
    else if Array.isArray(contact) && contact.length && (+(contact[0].params.expires || request.headers.expires || 300) > 0)
      userinfo.session = userinfo.session || {realm: realm}
      if !digest.authenticateRequest userinfo.session, request, {user: username, password: userinfo.password}
        sip.send digest.challenge userinfo.session, sip.makeResponse request, 401, 'Authentication Required'
      else
        userinfo.contact = contact
        rs = sip.makeResponse request, 200, 'Ok'
        rs.headers.contact = contact
        sip.send rs
    else
      delete userinfo.contact
      rs = sip.makeResponse request, 200, 'Ok'
      sip.send rs

  if request.method == 'INVITE'
    from = sip.parseUri(request.headers.from.uri).user
    contact = registry[from].contact

  	if !contact
      rs = sip.makeResponse request, 401, 'Unauthorized'
      sip.send rs
  	else
      rs = sip.makeResponse request, 404, 'Not found'
      sip.send rs