require '../util'

module.exports = (AdapterSync) ->

  'test get and set': ->
    adapterSync = new AdapterSync
    adapterSync.get().should.eql {}
    
    out = adapterSync.set 'color', 'green'
    out.should.eql 'green'
    adapterSync.get('color').should.eql 'green'
    
    out = adapterSync.set 'info.numbers', first: 2, second: 10
    out.should.eql first: 2, second: 10
    adapterSync.get('info.numbers').should.eql first: 2, second: 10
    adapterSync.get().should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    adapterSync.set 'info', 'new'
    adapterSync.get().should.eql color: 'green', info: 'new'

  'test del': ->
    adapterSync = new AdapterSync
    adapterSync.set 'color', 'green'
    adapterSync.set 'info.numbers', first: 2, second: 10
    
    adapterSync.del 'color'
    adapterSync.get().should.eql
      info:
        numbers:
          first: 2
          second: 10
    
    adapterSync.del 'info.numbers'
    adapterSync.get().should.eql info: {}
