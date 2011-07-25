Model = require 'Model'
wrapTest = require('./util').wrapTest
mockSocketModel = require('./util/model').mockSocketModel

module.exports =

  'transactions should be requested if pending longer than timeout': wrapTest (done) ->
    expected = 1
    [sockets, model] = mockSocketModel '', 'txnsSince', (txnsSince) ->
      txnsSince.should.eql expected
      sockets._disconnect()
      done()
    sockets.emit 'txn', [1, '_.0', 'set', 'color', 'green'], 1
    sockets.emit 'txn', [2, '_.0', 'set', 'color', 'red'], 2
    sockets.emit 'txn', [4, '_.0', 'set', 'color', 'blue'], 4
    sockets.emit 'txn', [5, '_.0', 'set', 'color', 'blue'], 5
    setTimeout (-> expected = 3), 0
  , 2