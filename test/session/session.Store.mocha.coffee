http = require 'http'
connect = require 'connect'
require './http'
{expect} = require '../util'
{changeEnvTo} = require '../util'
{indexOf} = require '../../lib/util'
{finishAfter} = require '../../lib/util/async'
_url = require 'url'
async = require 'async'

# A browser represents a series of clients on the same session, each with their
# own connection to a given app/server combo
Browser = (@browserName, @app, @server) ->
  return

Browser::createTab =  (clientName, callback) ->
  req = @app.request(@server).get("/?browserName=#{@browserName}&clientName=#{clientName}")
  req.set('cookie', "connect.sid=#{@sessionId}") if @sessionId
  req.end (res) =>
    @sessionId ||= sid res

    # Clear global io object, which otherwise would save sockets across separate tests
    delete require.cache[require.resolve 'socket.io-client']

    # Ensure a unique socket.io connection per tab
    global.io = require 'socket.io-client'
    __connect__ = global.io.connect
    global.io.connect = (path) ->
      out = __connect__.call @, "http://127.0.0.1:3000" + path
      @connect = __connect__
      return out
    ioUtil = global.io.util

    # Hack to set cookie for the future handshake request
    __request__ = ioUtil.request
    ioUtil.request = (xdomain) =>
      xhr = __request__.call ioUtil, xdomain
      xhr.setRequestHeader 'cookie', "connect.sid=#{@sessionId}"
      ioUtil.request = __request__
      return xhr

    # Init the bundle into a browser Model
    changeEnvTo 'browser'
    browserRacer = require '../../lib/racer'
    bundle = JSON.parse res.body
    clientId = bundle[0]
    browser = this
    browserRacer.on 'init', (browserModel) ->
      changeEnvTo 'server'
      callback null, new Tab(browser, clientName, browserModel)
    browserRacer.init bundle


Tab = (@browser, @clientName, @model) ->
  return

Tab::get = (path, callback) ->
  {app, server, sessionId} = @browser
  req = app.request(server).get(path)
  req.set('cookie', "connect.sid=#{sessionId}") if sessionId
  req.end (res) ->
    callback()


sid = (res) ->
  val = res.headers?['set-cookie']
  return '' unless val
  return /^connect\.sid=([^;]+);/.exec(val[0])[1]

setup = (browsers) ->
  # We have one app that all browsers connect to
  app = connect().use(connect.cookieParser())

  changeEnvTo 'server'
  racer = require '../../lib/racer'
  store = racer.createStore()

  app.use store.sessionMiddleware key: 'connect.sid', secret: 'xxx'
  app.use store.modelMiddleware()

  app.use '/logout', (req, res) ->
    req.session.destroy()
    res.end()

  # Maps model clientIds to the clientNames we give them for tests.
  idsToNames = {}

  # The last middleware for handling '/' requests. This is intended for each
  # tab's first request for the entire page.
  app.use (req, res, next) ->
    return next() if /socket.io/.test req.url
    {clientName, browserName} = _url.parse(req.url, true).query

    # Simulate bundling the server Model & sending it to the browser
    bundleModel = (serverModel) ->
      serverModel.bundle (bundle) -> res.end(bundle)

    serverModel = req.createModel()
    idsToNames[serverModel._clientId] = clientName
    browsers[browserName][clientName].server req, serverModel, bundleModel, store

  return run = ->
    tabs = {}

    webServer = http.createServer(app)
    webServer.listen 3000, ->
      store.listen webServer

      store.io.sockets.on 'connection', (socket) ->
        matchingClientName = idsToNames[socket.handshake.query.clientId]
        clients[matchingClientName].onSocketCxn socket, tabs[matchingClientName]

      series = {}
      for browserName of browsers
        browser = new Browser browserName, app, webServer
        clients = browsers[browserName]
        for clientName of clients
          series[clientName] = do (browser, clientName, clients) -> (callback) ->
            browser.createTab clientName, (err, tab) ->
              tabs[clientName] = tab
              clients[clientName].browser tab.model
              callback err, tab

      async.series series, (err, tabs) -> # tabs maps clientId -> tab

    return teardown = (cb) ->
      webServer.on 'close', cb
      webServer.close()

describe 'Server-side sessions', ->
  describe 'single client', ->
    describe 'access', ->
      beforeEach (done) ->
        run = setup
          browserA:
            tabA:
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

        @teardown = run()

      afterEach (done) ->
        @teardown(done)

      it 'should be shared between connect middleware and socket.io sockets', ->
        expect(@socketSession).to.equal @connectSession

      it 'should reject a request that tries to hi-jack a clientId via the socket.io uri endpoint'

    describe 'destroyed', ->
      describe 'via a http request', ->
        beforeEach (done) ->
          run = setup
            browserA:
              tabA:
                server: (req, serverModel, bundleModel, @store) =>
                  @connectSession = req.session
                  req.session.roles = ['admin']
                  serverModel.subscribe 'groups.1', (err, group) ->
                    bundleModel serverModel
                browser: (@model) =>
                onSocketCxn: (@socket, tab) =>
                  tab.get '/logout', done

          @teardown = run()

        afterEach (done) ->
          @teardown(done)

        it "should remove the session from the actor's socket", (done) ->
          expect(@socket).to.not.have.property('session')
          @socket.on 'disconnect', -> done()
          @socket.disconnect 'booted'

        it 'should clean up the secure clientId->sessionId pair in store', (done) ->
          expect(@store._securePairs).to.not.have.property(@model._clientId)
          @socket.on 'disconnect', -> done()
          @socket.disconnect 'booted'

    describe 'requests after a session destruction', ->
      it 'should create a new session'

    describe 'socket.io messages after a session destruction', ->
      it 'should be rejected'
      it 'should force a re-load'

    describe 'expiring', ->
      it 'should not expire a session as long as racer is sending messages over socket.io'

      it 'should refresh a session expiry upon each racer message receipt on socketio'

      it 'should destroy a session if a message is received over socketio and it is after an expiry'

      it 'should destroy a session if an http request is received over http'

      describe 'while a client is disconnected', ->

    describe 'upon expiry', ->
      it 'should remove the session from every associated socket'

  describe 'multi-client', ->
    describe 'destroyed', ->
      describe 'via a http request', ->
        it 'should remove the session from every associated socket aaa', (done) ->
          sockets = {}

          leavingTab = null

          run = setup
            browserA:
              tabA:
                server: (req, serverModel, bundleModel) ->
                  bundleModel serverModel
                browser: (model) ->
                onSocketCxn: (socket, tab) ->
                  sockets.x = socket
                  leavingTab = tab
                  wait()
              tabB:
                server: (req, serverModel, bundleModel) =>
                  bundleModel serverModel
                browser: (model) ->
                onSocketCxn: (socket, tab) ->
                  sockets.y = socket
                  wait()

          wait = finishAfter 2, ->
            leavingTab.get '/logout', ->
              expect(sockets.x).to.not.have.property('session')
              expect(sockets.y).to.not.have.property('session')
              finish = finishAfter Object.keys(sockets).length, ->
                teardown done
              for k of sockets
                sockets[k].on 'disconnect', finish
                sockets[k].disconnect 'booted'

          teardown = run()

        it 'should ask the browser to refresh itself to logout'

      describe 'over socket.io', ->
        it 'should remove the session from every associated socket'
        it 'subsequent http requests should create a new session'

    describe 'requests after a session destruction', ->
      it 'should create a new session'


    describe 're-logging in from another window', ->
      it 'should load the last page seen before the prior logout'
      it 'should load the home page in the window triggering the re-login'
