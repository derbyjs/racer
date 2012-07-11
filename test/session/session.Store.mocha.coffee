sinon = require 'sinon'
{expect} = require '../util'
{finishAfter} = require '../../lib/util/async'
setup = require '../util/singleProcessStack'

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
    it 'should keep client sessions independent of one another'

    describe 'destroyed', ->
      describe 'via a http request', ->

        # This protects against the case where a malicious user could
        # breakpoint the browser before it can reload the page because the
        # server asked it to (see the test after this one)
        it 'should remove the session from every associated socket', (done) ->
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

        it 'should ask the other browsers to reload the page', (done) ->
          sockets = {}

          leavingTab = null

          modelB = null

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
                  modelB = model
                onSocketCxn: (socket, tab) ->
                  sockets.y = socket
                  wait()

          wait = finishAfter 2, ->
            spy = sinon.spy()
            modelB.socket.on 'reload', ->
              spy()
              finish = finishAfter Object.keys(sockets).length, ->
                expect(spy).to.be.calledOnce()
                teardown done
              for k of sockets
                sockets[k].on 'disconnect', finish
                sockets[k].disconnect 'booted'
            leavingTab.get '/logout', ->

          teardown = run()

      describe 'over socket.io', ->
        it 'should remove the session from every associated socket'
        it 'subsequent http requests should create a new session'

    describe 'requests after a session destruction', ->
      it 'should create a new session'


    describe 're-logging in from another window', ->
      it 'should load the last page seen before the prior logout'
      it 'should load the home page in the window triggering the re-login'
