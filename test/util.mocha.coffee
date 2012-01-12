util = require '../src/util'
should = require 'should'

describe 'util', ->

  describe 'util.merge', ->

    it 'merges empty objects', ->
      a = {}
      b = {}
      util.merge(a, b).should.eql {}
    
    it 'merges an empty object with a populated object', ->
      fn = (x) -> x++
      a = {}
      b = x: 's', y: [1, 3], fn: fn
      util.merge(a, b).should.eql x: 's', y: [1, 3], fn: fn

    it 'merges a populated object with a populated object', ->
      fn = (x) -> x++
      a = x: 's', y: [1, 3], fn: fn
      b = x: 7, z: {}
      util.merge(a, b).should.eql x: 7, y: [1, 3], fn: fn, z: {}

      # Merge should modify the first argument
      a.should.eql x: 7, y: [1, 3], fn: fn, z: {}
      # But not the second
      b.should.eql x: 7, z: {}

  describe 'util.hasKeys', ->

    it 'detects whether an object has any properties', ->
      util.hasKeys({}).should.be.false
      util.hasKeys({a: undefined}).should.be.true
      util.hasKeys({a: 1, b: {}}).should.be.true

    it 'supports an ignore option', ->
      util.hasKeys({a: 2}).should.be.true
      util.hasKeys({a: 2}, 'a').should.be.false
      util.hasKeys({a: 2, b: 3}, 'a').should.be.true
