{expect} = require '../util'
setup = require '../util/singleProcessStack'

# TODO Test with contexts

describe 'access control', ->
  describe 'for queries', ->
    describe 'synchronous predicates', ->
      describe 'acceptable Model fetches', ->
        it 'should work on the first page load'
#          run = setup
#            config: (racer, store) ->
#              store.allowRead 'users', 'withRole', (role) ->
#                return -1 != @session.roles.indexOf 'superadmin'
#            browserA:
#              tabA:
#                server: (req, serverModel, bundleModel) ->
#                  req.session.userId = 'A'
#                  q = serverModel.query('users').withRole('basic')
#                  serverModel.fetch q, (err, basicUsers) ->
#                    expect(err).to.be.null()
#                    done()

        it 'should work after the page load'
#          run = setup
#            config: (racer, store) ->
#              store.context 'admin', ->
#                store.allowRead 'users', 'withRole', (role) ->
#                  return -1 != @session.roles.indexOf 'superadmin'
#            browserA:
#              tabA:
#                server: (req, serverModel, bundleModel) ->
#                  req.session.userId = 'A'
#                browser: (model) ->
#                onSocketCxn: (socket) ->
#                ready: (model) ->
#                  q = model.query('users').withRole('basic')
#                  model.fetch q, (err, basicUsers) ->
#                    expect(err).to.be.null()
#                    expect(basicUsers).to.have.length(0)
#                    done()

      describe 'forbiddenn Model fetches', ->
        it 'should send the user to a forbidden page on the first page load'

        it 'should send an auth error to the client after the page load'
#          run = setup
#            config: (racer, store) ->
#              store.context 'admin', ->
#                store.allowRead 'users', 'withRole', (role) ->
#                  return -1 != @session.roles.indexOf 'superadmin'
#            browserA:
#              tabA:
#                server: (req, serverModel, bundleModel) ->
#                  req.session.userId = 'A'
#                browser: (model) ->
#                onSocketCxn: (socket) ->
#                ready: (model) ->
#                  q = model.query('users').withRole('basic')
#                  model.fetch q, (err, basicUsers) ->
#                    expect(err).to.equal 'Unauthorized access'
#                    expect(basicUsers).to.be(undefined)
#                    done()

      describe 'acceptable Model subscribes', ->

      describe 'forbiddenn Model subscribes', ->

    describe 'asynchronous predicates', ->

  describe 'reading paths', ->
    describe 'asynchronous predicates', ->
      describe 'acceptable Model fetches', ->
        it 'should work on the first page load aaa', (done) ->
          run = setup
            config: (racer, store) ->
              store.readPathAccess 'users.*.ssn', (userId, allow) ->
                return allow(-1 != @session.roles.indexOf 'superadmin')
            browserA:
              tabA:
                server: (req, serverModel, bundleModel, store) ->
                  store.set 'users.1.ssn', 'xxx', null, (err) ->
                    expect(err).to.be.null()
                    req.session.roles = ['superadmin']
                    serverModel.fetch 'users.1.ssn', (err, basicUsers) ->
                      expect(err).to.be.null()
                      bundleModel serverModel
                browser: (model) ->
                  expect(model.get('users.1.ssn')).to.equal 'xxx'
                onSocketCxn: (socket) ->
                  socket.on 'disconnect', ->
                    teardown done
                  socket.disconnect 'booted'

          teardown = run()

      describe 'forbidden Model fetches', ->
        it 'should fail on the first page load bbb', (done) ->
          run = setup
            config: (racer, store) ->
              store.readPathAccess 'users.*.ssn', (userId, allow) ->
                return allow(-1 != @session.roles.indexOf 'superadmin')
            browserA:
              tabA:
                server: (req, serverModel, bundleModel, store) ->
                  store.set 'users.1.ssn', 'xxx', null, (err) ->
                    expect(err).to.be.null()
                    req.session.roles = ['superadmin']
                    serverModel.fetch 'users.1.ssn', (err, basicUsers) ->
                      expect(err).to.not.be.null()
                      expect(err).to.equal 'Unauthorized'
                      bundleModel serverModel
                browser: (model) ->
                  expect(model.get('users.1.ssn')).to.eql undefined
                onSocketCxn: (socket) ->
                  socket.on 'disconnect', ->
                    teardown done
                  socket.disconnect 'booted'
          teardown = run()

    describe 'synchronous predicates', ->

  describe 'allowWrite', ->
    describe 'synchronous predicates', ->
    describe 'asynchronous predicates', ->
