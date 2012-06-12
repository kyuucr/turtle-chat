util = require 'util'
os = require 'os'
express = require 'express'
stylus = require 'stylus'
assets = require 'connect-assets'
sip = require 'sip-websocket'
digest = require 'sip-websocket/digest'

bold  = '\x1B[0;1m'
red   = '\x1B[0;31m'
green = '\x1B[0;32m'
reset = '\x1B[0m'

registry = {
  '100': {password: '1234'},
  '101':  {password:  'qwerty'}
}
users = []
realm = os.hostname()

app = express.createServer()
app.use assets()
app.set 'view engine', 'jade'
app.use express.static __dirname + '/public'

app.get '/', (req, resp) -> resp.render 'phone', {title: 'turtle-chat'}

app.listen process.env.VMC_APP_PORT or 3000, -> util.debug bold + 'Webserver listening on port ' + app.address().port + ' ...' + reset

sip.start { websocket: app }
  , (request, remote) ->
    util.debug bold + 'Receiving request from ' + remote.address + ':' + remote.port + ' Protocol: ' + remote.protocol + reset + '\n' + sip.stringify request

    if request.headers['max-forwards'] <= 0
      # max forward reached 0, make 483 response
      return sip.send sip.makeResponse request, 483, 'Too many hops'

    if sip.stringify(request).length > 8192
      # max sip message length reached, make response
      return sip.send sip.makeResponse request, 513, 'Message overflow'

    if request.method == 'REGISTER'
      username = sip.parseUri(request.headers.to.uri).user
      userinfo = registry[username]
      contact = request.headers.contact
      
      if !userinfo
        return sip.send sip.makeResponse request, 404, 'Not found'
      else if Array.isArray(contact) && contact.length && (+(contact[0].params.expires || request.headers.expires || 300) > 0)
        if(userinfo.session == undefined)
          userinfo.session = {realm: realm}
          digest.authenticateRequest userinfo.session, request, {user: username, password: userinfo.password}
          return sip.send digest.challenge userinfo.session, sip.makeResponse request, 401, 'Authentication Required'
        else
          if !digest.authenticateRequest userinfo.session, request, {user: username, password: userinfo.password}
            delete userinfo.session
            return sip.send sip.makeResponse request, 401, 'Authentication Unsuccesful'
          else
            delete userinfo.session
            # user recognized, send 200 response
            rs = sip.makeResponse request, 200, 'Ok'
            if (remote.protocol == 'WS')
              # if protocol is websocket, change contact to real address
              contact[0].uri = 'sip:' + username + '@' + remote.address + ':' + remote.port + ';transport=ws'
              contact[0].params['pub-gruu'] = request.headers.to.uri
              contact[0].params['gr'] = contact[0].params['+sip.instance']
              rs.headers.contact = contact
            users[request.headers.to.uri] = contact[0]
            return sip.send rs
      else
        delete users[request.headers.to.uri]
        delete userinfo.session
        return sip.send sip.makeResponse request, 200, 'Ok'

    from = users[request.headers.from.uri]
    to = users[request.headers.to.uri]
    
    if request.method == 'INVITE'
      if !from
        return sip.send sip.makeResponse request, 401, 'Please register to use our server'
      else if !to
        return sip.send sip.makeResponse request, 404, 'Not found'

    request.uri = to.uri

    return sip.send request, (response) ->
      util.debug bold + 'Handling response:' + reset + '\n' + sip.stringify response
      response.headers.via.shift()
      sip.send response

  , (options) ->
    util.debug bold + 'SIP server listening on:' + reset
    isUdp = (options.udp == undefined) || options.udp
    isTcp = (options.tcp == undefined) || options.tcp
    port = options.port || 5060
    if isUdp || isTcp
      util.debug bold + ('UDP ' if isUdp) + ('TCP ' if isTcp) + 'port ' + port + ' ...' + reset
    if options.websocket
      util.debug bold + 'WS port ' + options.websocket.address().port + ' ...' + reset