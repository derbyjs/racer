{expect} = require './util'
{mockSocketModel} = require './util/model'

describe 'Model pubSub', ->

  it 'sub event should be sent on socket.io connect', (done) ->
    [model, sockets] = mockSocketModel '0', 'sub', (clientId, storeSubs, ver) ->
      expect(clientId).to.eql '0'
      expect(storeSubs).to.eql []
      expect(ver).to.eql 0
      sockets._disconnect()
      done()
