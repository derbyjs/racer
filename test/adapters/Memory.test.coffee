Memory = require 'adapters/Memory'
wrapTest = require('../util').wrapTest

module.exports =

  'test sync get': ->
    memory = new Memory
    memory._data.should.eql {}
    memory._data =
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    memory.get('color').should.eql 'green'
    memory.get('info.numbers').should.eql first: 2, second: 10
    memory.get().should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10

  'test sync set': ->
    memory = new Memory
    
    memory.set 'color', 'green'
    memory._data.should.eql color: 'green'
    
    memory.set 'info.numbers', first: 2, second: 10
    memory._data.should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    memory.set 'info', 'new'
    memory._data.should.eql
      color: 'green'
      info: 'new'

  'test sync del': ->
    memory = new Memory
    memory._data =
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    memory.del 'color'
    memory._data.should.eql
      info:
        numbers:
          first: 2
          second: 10
    
    memory.del 'info.numbers'
    memory._data.should.eql
      info: {}
