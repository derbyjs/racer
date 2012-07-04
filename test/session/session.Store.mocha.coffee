http = require 'http'
connect = require 'connect'
require './http'
{expect} = require '../util'
{changeEnvTo} = require '../util'
{indexOf} = require '../../lib/util'
{finishAfter} = require '../../lib/util/async'
_url = require 'url'

sid = (res) ->
  val = res.headers?['set-cookie']
  return '' unless val
  return /^connect\.sid=([^;]+);/.exec(val[0])[1]


openPage = (app, {clients}) ->
  idsToNames = {}

  changeEnvTo 'server'
  racer = require '../../lib/racer'
  store = racer.createStore()
  sessMiddleware = store.sessionMiddleware key: 'connect.sid', secret: 'xxx'

  app.use sessMiddleware
  app.use store.modelMiddleware()

  app.use (req, res, next) ->
    return next() if /socket.io/.test req.url
    clientName = _url.parse(req.url, true).query.clientName

    # Simulate bundling the server Model & sending it to the browser
    bundleModel = (serverModel) ->
      serverModel.bundle (bundle) ->
        res.end(bundle) # GOTO XXX


    serverModel = req.createModel()
    idsToNames[serverModel._clientId] = clientName
    clients[clientName].server req, serverModel, bundleModel

  @io = require 'socket.io-client'
  __connect__ = @io.connect
  @io.connect = (path) ->
    __connect__.call @, "http://127.0.0.1:3000" + path
  ioUtil = @io.util

  return run = (cb) ->
    webServer = http.createServer(app)
    webServer.listen 3000, ->
      store.listen webServer

      # Hack to write a cookie from the browser with an XHR
      __handleHandshake__ = store.io.handleHandshake
      store.io.handleHandshake = (data, req, res) ->
        if xCookie = req.headers['x-cookie']
          req.headers['Cookie'] = xCookie
        __handleHandshake__.call this, data, req, res

      store.io.sockets.on 'connection', (socket) ->
        matchingClientName = idsToNames[socket.handshake.query.clientId]
        clients[matchingClientName].onSocketCxn socket
      setTimeout ->

      for clientName of clients
        app.request(webServer).get("/?clientName=#{clientName}").end (res) ->
          # Hack to set cookie for the future handshake request
          __request__ = ioUtil.request
          ioUtil.request = (xdomain) ->
            xhr = __request__.call ioUtil, xdomain
            xhr.setRequestHeader 'cookie', "connect.sid=#{sid res}"
            ioUtil.request = __request__
            return xhr

          # Init the bundle into a browser Model
          changeEnvTo 'browser'
          browserRacer = require '../../lib/racer'
          bundle = JSON.parse res.body
          clientId = bundle[0]
          clientName = idsToNames[clientId]
          browserRacer.on 'init', (browserModel) ->
            changeEnvTo 'server'
            clients[clientName].browser browserModel
          browserRacer.init bundle


      cb webServer

describe 'Server-side sessions', ->

  describe 'access', ->
    beforeEach (done) ->
      app = connect().use(connect.cookieParser())

      run = openPage app,
        clients:
          x:
            server: (req, serverModel, bundleModel) =>
              @connectSession = req.session
              req.session.roles = ['admin']
              serverModel.subscribe 'groups.1', (err, group) ->
                bundleModel serverModel
            browser: (model) ->
            onSocketCxn: (socket) =>
              @socketSession = socket.session
              socket.on 'disconnect', -> done()
              socket.disconnect 'booted'

      run (server) =>
        @server = server

    afterEach (done) ->
      @server.on 'close', done
      @server.close()

    it 'should be shared between connect middleware and socket.io sockets', ->
      expect(@socketSession).to.equal @connectSession

    it 'should reject a request that tries to hi-jack a clientId via the socket.io uri endpoint'

  describe 'destroyed', ->
    describe 'via an http request', ->
#      before (done) ->
#        @app.request().get('/logout').end (res) ->
#          done()

      it 'should remove the session from every associated socket'

      it 'subsequent http requests should create a new session'

      it 'should ask the browser to refresh itself to logout'

    describe 'over socket.io', ->
      it 'should remove the session from every associated socket'
      it 'subsequent http requests should create a new session'

  describe 'expiring', ->
    it 'should not expire a session as long as racer is sending messages over socket.io'

    it 'should refresh a session expiry upon each racer message receipt on socketio'

    it 'should destroy a session if a message is received over socketio and it is after an expiry'

    it 'should destroy a session if an http request is received over http'

    describe 'while a client is disconnected', ->

  describe 'upon expiry', ->
    it 'should remove the session from every associated socket'

  describe 're-logging in from another window', ->
    it 'should load the last page seen before the prior logout'
    it 'should load the home page in the window triggering the re-login'
