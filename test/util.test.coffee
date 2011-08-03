util = require '../src/util'
should = require 'should'

module.exports =
  
  'test merging empty objects': ->
    a = {}
    b = {}
    util.merge(a, b).should.eql {}
  
  'test merging an empty object with a populated object': ->
    fn = (x) -> x++
    a = {}
    b = x: 's', y: [1, 3], fn: fn
    util.merge(a, b).should.eql x: 's', y: [1, 3], fn: fn
    
  'test merging a populated object with a populated object': ->
    fn = (x) -> x++
    a = x: 's', y: [1, 3], fn: fn
    b = x: 7, z: {}
    util.merge(a, b).should.eql x: 7, y: [1, 3], fn: fn, z: {}
    
    # Merge should modify the first argument
    a.should.eql x: 7, y: [1, 3], fn: fn, z: {}
    # But not the second
    b.should.eql x: 7, z: {}
  
  'test hasKeys': ->
    util.hasKeys({}).should.be.false
    util.hasKeys({a: undefined}).should.be.true
    util.hasKeys({a: 1, b: {}}).should.be.true
