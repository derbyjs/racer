http = require 'http'
connect = require 'connect'
{changeEnvTo} = require '../util'
require '../session/http'
_url = require 'url'
async = require 'async'

module.exports = (browsers) ->
  # We have one app that all browsers connect to
  app = connect().use(connect.cookieParser())

  changeEnvTo 'server'
  racer = require '../../lib/racer'
  store = racer.createStore()

  if config = browsers.config
    config racer, store

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

    serverModel = req.getModel()
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
        continue if browserName == 'setup'
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
      # TODO Comment this out if we're to run tests with reconnects
      ioUtil.request = __request__
      return xhr

    # Init the bundle into a browser Model
    changeEnvTo 'browser'
    browserRacer = require '../../lib/racer'
    try
      bundle = JSON.parse res.body
    catch e
      console.log res.body
      throw e
    clientId = bundle[0]
    browser = this
    browserRacer.on 'init', (browserModel) ->
      #browserModel.connect = (cb) ->
        #socket.once 'connect', cb if cb
        # socketConnect()
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
