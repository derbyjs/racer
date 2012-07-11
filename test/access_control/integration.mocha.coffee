{expect} = require '../util'
setup = require '../util/singleProcessStack'

# TODO Test with contexts

describe 'access control', ->
  ['fetch', 'subscribe'].forEach (reader) ->
    describe "authorized Model #{reader} paths", ->
      describe 'synchronous predicates', ->
      describe 'asynchronous predicates', ->
        it 'should work on the first page load', (done) ->
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
                    serverModel[reader] 'users.1.ssn', (err, basicUsers) ->
                      expect(err).to.be.null()
                      bundleModel serverModel
                browser: (model) ->
                  expect(model.get('users.1.ssn')).to.equal 'xxx'
                onSocketCxn: (socket) ->
                  socket.on 'disconnect', ->
                    teardown done
                  socket.disconnect 'booted'

          teardown = run()

        it 'should work after the page loads', (done) ->
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
                    bundleModel serverModel
                browser: (model) ->
                onSocketCxn: (socket, tab) ->
                  model = tab.model
                  model.on 'connected', ->
                    model[reader] 'users.1.ssn', (err, ssn) ->
                      expect(err).to.be.null()
                      expect(ssn.get()).to.equal 'xxx'
                      socket.on 'disconnect', ->
                        teardown done
                      socket.disconnect 'booted'

          teardown = run()

    describe "forbidden Model #{reader} paths", ->
      describe 'asynchronous predicates', ->
        it 'should fail on the first page load', (done) ->
          run = setup
            config: (racer, store) ->
              store.readPathAccess 'users.*.ssn', (userId, allow) ->
                return allow(-1 != @session.roles.indexOf 'superadmin')
            browserA:
              tabA:
                server: (req, serverModel, bundleModel, store) ->
                  store.set 'users.1.ssn', 'xxx', null, (err) ->
                    expect(err).to.be.null()
                    req.session.roles = ['guest']
                    serverModel[reader] 'users.1.ssn', (err, basicUsers) ->
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

        it 'should work after the page loads', (done) ->
          run = setup
            config: (racer, store) ->
              store.readPathAccess 'users.*.ssn', (userId, allow) ->
                return allow(-1 != @session.roles.indexOf 'superadmin')
            browserA:
              tabA:
                server: (req, serverModel, bundleModel, store) ->
                  store.set 'users.1.ssn', 'xxx', null, (err) ->
                    expect(err).to.be.null()
                    req.session.roles = ['guest']
                    bundleModel serverModel
                browser: (model) ->
                onSocketCxn: (socket, tab) ->
                  model = tab.model
                  model.on 'connected', ->
                    model[reader] 'users.1.ssn', (err, scopedModel) ->
                      expect(err).to.equal 'Unauthorized'
                      expect(scopedModel).to.eql undefined
                      socket.on 'disconnect', ->
                        teardown done
                      socket.disconnect 'booted'
          teardown = run()


    describe "authorized Model #{reader} queries", ->
      describe 'asynchronous predicates', ->
      describe 'asynchronous predicates', ->
        it "should work when #{reader} originates on the server aaa", (done) ->
          run = setup
            config: (racer, store) ->
              store.query.expose 'users', 'withRole', (role) ->
                return @where('roles').contains([role])
              store.queryAccess 'users', 'withRole', (role, allow) ->
                return allow(-1 != @session.roles.indexOf 'superadmin')
            browserA:
              tabA:
                server: (req, serverModel, bundleModel, store) ->
                  store.set 'users.1', {id: '1', roles: ['superadmin']}, null, (err) ->
                    expect(err).to.be.null()
                    req.session.roles = ['superadmin']
                    query = serverModel.query('users').withRole('superadmin')
                    serverModel[reader] query, (err, basicUsers) ->
                      expect(err).to.be.null()
                      bundleModel serverModel
                browser: (model) ->
                  expect(model.get('users.1')).to.eql id: '1', roles: ['superadmin']
                onSocketCxn: (socket) ->
                  socket.on 'disconnect', ->
                    teardown done
                  socket.disconnect 'booted'

          teardown = run()

        it 'should work after the page load', (done) ->
          run = setup
            config: (racer, store) ->
              store.query.expose 'users', 'withRole', (role) ->
                return @where('roles').contains([role])
              store.queryAccess 'users', 'withRole', (role, allow) ->
                return allow(-1 != @session.roles.indexOf 'superadmin')
            browserA:
              tabA:
                server: (req, serverModel, bundleModel, store) ->
                  store.set 'users.1', {id: '1', roles: ['superadmin']}, null, (err) ->
                    expect(err).to.be.null()
                    req.session.roles = ['superadmin']
                    bundleModel serverModel
                browser: (model) ->
                onSocketCxn: (socket, tab) ->
                  model = tab.model
                  model.on 'connected', ->
                    query = model.query('users').withRole('superadmin')
                    model[reader] query, (err, basicUsers) ->
                      expect(err).to.be.null()
                      expect(model.get('users.1')).to.eql id: '1', roles: ['superadmin']
                      socket.on 'disconnect', ->
                        teardown done
                      socket.disconnect 'booted'

          teardown = run()

    describe "forbiddenn Model #{reader} queries", ->
      describe 'synchronous predicates', ->
      describe 'asynchronous predicates', ->
        it 'should work on the first page load', (done) ->
          run = setup
            config: (racer, store) ->
              store.query.expose 'users', 'withRole', (role) ->
                return @where('roles').contains([role])
              store.queryAccess 'users', 'withRole', (role, allow) ->
                return allow(-1 != @session.roles.indexOf 'superadmin')
            browserA:
              tabA:
                server: (req, serverModel, bundleModel, store) ->
                  store.set 'users.1', {id: '1', roles: ['superadmin']}, null, (err) ->
                    expect(err).to.be.null()
                    req.session.roles = ['guest']
                    query = serverModel.query('users').withRole('superadmin')
                    serverModel[reader] query, (err, basicUsers) ->
                      expect(err).to.equal 'Unauthorized'
                      bundleModel serverModel
                browser: (model) ->
                  expect(model.get('users.1')).to.eql undefined
                onSocketCxn: (socket) ->
                  socket.on 'disconnect', ->
                    teardown done
                  socket.disconnect 'booted'

          teardown = run()

        it 'should work after the page load', (done) ->
          run = setup
            config: (racer, store) ->
              store.query.expose 'users', 'withRole', (role) ->
                return @where('roles').contains([role])
              store.queryAccess 'users', 'withRole', (role, allow) ->
                return allow(-1 != @session.roles.indexOf 'superadmin')
            browserA:
              tabA:
                server: (req, serverModel, bundleModel, store) ->
                  store.set 'users.1', {id: '1', roles: ['superadmin']}, null, (err) ->
                    expect(err).to.be.null()
                    req.session.roles = ['guest']
                    bundleModel serverModel
                browser: (model) ->
                  expect(model.get('users.1')).to.eql undefined
                onSocketCxn: (socket, tab) ->
                  model = tab.model
                  model.on 'connected', ->
                    query = model.query('users').withRole('superadmin')
                    model[reader] query, (err, users) ->
                      expect(err).to.equal 'Unauthorized'
                      expect(model.get('users.1')).to.eql undefined
                      socket.on 'disconnect', ->
                        teardown done
                      socket.disconnect 'booted'

          teardown = run()

        it 'should send the user to a forbidden page on the first page load'

        it 'should send an auth error to the client after the page load'

    describe 'allowWrite', ->
      describe 'synchronous predicates', ->
      describe 'asynchronous predicates', ->
