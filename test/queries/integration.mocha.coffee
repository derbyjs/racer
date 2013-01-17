{expect} = require '../util'
setup = require '../util/singleProcessStack'

describe 'bundling of filters', ->
  it 'should be able to unbundle the same filter in the browser xxx', (done) ->
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
