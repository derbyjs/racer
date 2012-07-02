http = require 'http'
connect = require 'connect'
require './http'
{expect} = require '../util'
{changeEnvTo} = require '../util'
{indexOf} = require '../../lib/util'

sid = (res) ->
  val = res.headers?['set-cookie']
  return '' unless val
  return /^connect\.sid=([^;]+);/.exec(val[0])[1]

openPage = (app, {server, browser}) ->
  changeEnvTo 'server'
  racer = require '../../lib/racer'
  store = racer.createStore listen: app

  unless app.cookieShim
    app.stack.unshift
      route: '/'
      handle: (req, res, next) ->
        if xCookie = req.headers['x-cookie']
          req.headers['Cookie'] = xCookie
        next()
    app.cookieShim = true

  sessMiddleware = store.sessionMiddleware key: 'connect.sid', secret: 'xxx'
  app.use sessMiddleware
  # TODO Clean up later
  sessMiddleware.cleanup = ->
    spliceIndex = indexOf app.stack, sessMiddleware, (sMw, {handle}) -> (sMw == handle)

  app.use (req, res) ->
    models = server: [], browser: []
    i = server.length - 3
    models.server.push store.createModel() while i--
    modelIds = (id for {id} in models.server)
    models.browser.insert = (browserModel) ->
      insertIndex = modelIds.indexOf browserModel.id
      models.browser[insertIndex] = browserModel

    # Simulate bundling the server Model & sending it to the browser
    bundleModel = (serverModel) ->
      serverModel.bundle (bundle) ->
        res.end()


        # Hack to set cookie for the future handshake request
        ioUtil = @io.util
        __request__ = ioUtil.request
        ioUtil.request = (xdomain) ->
          xhr = __request__.call ioUtil, xdomain
          xhr.setRequestHeader 'x-cookie', "connect.sid=#{sid res}"
          ioUtil.request = __request__
          return xhr

        changeEnvTo 'browser'
        racer = require '../../lib/racer'
        racer.on 'init', (browserModel) ->
          models.browser.insert browserModel
          changeEnvTo 'server'
          racer = require '../../lib/racer'
          browser models.browser...

        # Init the bundle into a browser Model
        racer.init JSON.parse bundle

    server models.server..., bundleModel, store, req.session

  @io = require 'socket.io-client'
  __connect__ = @io.connect
  @io.connect = (path) ->
    __connect__.call @, "http://localhost:#{3000}" + path

describe 'Server-side sessions', ->
  beforeEach (done) ->
    @app = connect().use(connect.cookieParser())

    openPage @app,
      server: (model, bundleModel, store, connectSession) =>
        model.subscribe 'groups.1', (err, group) ->
          bundleModel model
        store.io.sockets.on 'connection', (socket) =>
          @socketSession = socket.session
          @connectSession = connectSession
          done()
      browser: (model) ->

    http.createServer(@app).listen 3000
    @app.request().get('/').end (res) -> done()

  afterEach = (done) ->
    @app.close done

  describe 'access', ->
    it 'should be shared between connect middleware and socket.io sockets', ->
      expect(@socketSession).to.equal @connectSession

  describe 'destroyed', ->
    describe 'via an http request', ->
      it 'should remove the session from every associated socket'
      it 'subsequent http requests should create a new session'

    describe 'over socket.io', ->
      it 'should remove the session from every associated socket'
      it 'subsequent http requests should create a new session'

  describe 'expiring', ->
    it 'should not expire a session as long as racer is sending messages over socket.io'

    it 'should refresh a session expiry upon each racer message receipt on socketio'

    it 'should destroy a session if a message is received over socketio and it is after an expiry'

    it 'should destroy a session if an http request is received over http'

  describe 'upon expiry', ->
    it 'should remove the session from every associated socket'
