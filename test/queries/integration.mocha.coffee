{expect} = require '../util'
setup = require '../util/singleProcessStack'
{finishAfter} = require '../../lib/util/async'

describe 'filter integration', ->
  describe 'bundling', ->
    it 'should be able to unbundle the same function-powered filter in the browser', (done) ->
      run = setup
        browserA:
          tabA:
            server: (req, serverModel, bundleModel, store) ->
              store.set 'users.1.name', 'Brian', null, (err) ->
                expect(err).to.be.null()
                store.set 'users.2.name', 'Nate', null, (err) ->
                  serverModel.fetch 'users', (err, users) ->
                    filter = serverModel.filter 'users', (user) ->
                      user.name.charAt(0) == 'B'
                    serverModel.ref '_b', filter
                    expect(serverModel.get('_b.length')).to.equal 1
                    expect(serverModel.get('_b.0.name')).to.equal 'Brian'
                    bundleModel serverModel
            browser: (model) ->
              expect(model.get('_b.length')).to.equal 1
              expect(model.get('_b.0.name')).to.equal 'Brian'
            onSocketCxn: (socket) ->
              socket.on 'disconnect', ->
                teardown done
              socket.disconnect 'booted'

      teardown = run()

    it 'should be able to leverage the model inside a filter function in the browser', (done) ->
      run = setup
        browserA:
          tabA:
            server: (req, serverModel, bundleModel, store) ->
              store.set 'users.1.name', 'Brian', null, (err) ->
                expect(err).to.be.null()
                store.set 'users.2.name', 'Nate', null, (err) ->
                  serverModel.set '_letter', 'B'
                  serverModel.fetch 'users', (err, users) ->
                    filter = serverModel.filter 'users', (user, id, model) ->
                      user.name.charAt(0) == model.get '_letter'
                    serverModel.ref '_b', filter
                    expect(serverModel.get('_b.length')).to.equal 1
                    expect(serverModel.get('_b.0.name')).to.equal 'Brian'
                    bundleModel serverModel
            browser: (model) ->
              expect(model.get('_b.length')).to.equal 1
              expect(model.get('_b.0.name')).to.equal 'Brian'
            onSocketCxn: (socket) ->
              socket.on 'disconnect', ->
                teardown done
              socket.disconnect 'booted'

      teardown = run()

  describe 'preservation', ->
    it 'should be able to load the same filtered results in the browser', (done) ->
      run = setup
        browserA:
          tabA:
            server: (req, serverModel, bundleModel, store) ->
              store.query.expose 'users',
                olderThan: (age) -> @where('age').gt(age)
              store.set 'users.b', id: 'b', name: 'Brian', age: 27, null, (err) ->
                expect(err).to.be.null()
                store.set 'users.n', id: 'n', name: 'Nate', age: 28, null, (err) ->
                  serverModel.query('users').olderThan(25).fetch (err, $users) ->
                    serverModel.set '_letter', 'B'
                    filter = serverModel.filter $users, (user, id, model) ->
                      user.name.charAt(0) == model.get '_letter'
                    serverModel.ref '_b', filter
                    expect(serverModel.get('_b.length')).to.equal 1
                    expect(serverModel.get('_b.0.name')).to.equal 'Brian'
                    bundleModel serverModel
            browser: (model) ->
              expect(model.get('_b.length')).to.equal 1
              expect(model.get('_b.0.name')).to.equal 'Brian'
              expect(model.get('_b')).to.specEql [{id: 'b', name: 'Brian', age: 27}]
            onSocketCxn: (socket) ->
              socket.on 'disconnect', ->
                teardown done
              socket.disconnect 'booted'

      teardown = run()

  describe 'reacting', ->
    it 'filters on queries should react to changes from other tabs', (done) ->
      sockets = {}
      tabs = {}
      models = {}
      run = setup
        browser:
          tabA:
            server: (req, serverModel, bundleModel, store) ->
              store.query.expose 'users', named: (name) -> @where('name').equals('Brian')
              store.set 'users.1.name', 'Ryan', null, (err) ->
                expect(err).to.be.null()
                query = serverModel.query('users').named('Brian')
                serverModel.subscribe query, (err, $results) ->
                  filter = $results.filter (user, id, model) ->
                    user.name in ['Bri' + 'an', 'Bryan']
                  serverModel.ref '_b', filter
                  expect(serverModel.get('_b.length')).to.equal 0
                  bundleModel serverModel
            browser: (model) ->
              models.A = model
              expect(model.get('_b.length')).to.equal 0
            onSocketCxn: (socket, tab) ->
              sockets.A = socket
              tabs.A = tab
              wait()
          tabB:
            server: (req, serverModel, bundleModel, store) ->
              store.set 'users.1.name', 'Ryan', null, (err) ->
                expect(err).to.be.null()
                query = serverModel.query('users').named('Brian')
                serverModel.subscribe query, (err, $results) ->
                  bundleModel serverModel
            browser: (model) ->
              models.B = model
            onSocketCxn: (socket, tab) ->
              sockets.B = socket
              tabs.B = tab
              wait()

        wait = finishAfter 2, ->
          models.A.on 'insert', '_b', ->
            finish = finishAfter Object.keys(sockets).length, ->
              teardown done
            for k, socket of sockets
              socket.on 'disconnect', finish
              socket.disconnect 'booted'
          models.B.set 'users.1.name', 'Brian'

      teardown = run()
