MemorySync = require 'adapters/MemorySync'
wrapTest = require('../util').wrapTest

module.exports =

  'test sync get': ->
    memorySync = new MemorySync
    memorySync._data.should.eql {}
    memorySync._data =
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    memorySync.get('color').should.eql 'green'
    memorySync.get('info.numbers').should.eql first: 2, second: 10
    memorySync.get().should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10

  'test sync set': ->
    memorySync = new MemorySync
    
    memorySync.set 'color', 'green'
    memorySync._data.should.eql color: 'green'
    
    memorySync.set 'info.numbers', first: 2, second: 10
    memorySync._data.should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    memorySync.set 'info', 'new'
    memorySync._data.should.eql
      color: 'green'
      info: 'new'

  'test sync del': ->
    memorySync = new MemorySync
    memorySync._data =
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    memorySync.del 'color'
    memorySync._data.should.eql
      info:
        numbers:
          first: 2
          second: 10
    
    memorySync.del 'info.numbers'
    memorySync._data.should.eql
      info: {}
