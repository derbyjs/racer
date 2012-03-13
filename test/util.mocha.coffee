{expect} = require './util'
util = require '../lib/util'

describe 'util', ->

  describe 'util.merge', ->

    it 'merges empty objects', ->
      a = {}
      b = {}
      expect(util.merge a, b).to.eql {}

    it 'merges an empty object with a populated object', ->
      fn = (x) -> x++
      a = {}
      b = x: 's', y: [1, 3], fn: fn
      expect(util.merge a, b).to.eql x: 's', y: [1, 3], fn: fn

    it 'merges a populated object with a populated object', ->
      fn = (x) -> x++
      a = x: 's', y: [1, 3], fn: fn
      b = x: 7, z: {}
      expect(util.merge a, b).to.eql x: 7, y: [1, 3], fn: fn, z: {}

      # Merge should modify the first argument
      expect(a).to.eql x: 7, y: [1, 3], fn: fn, z: {}
      # But not the second
      expect(b).to.eql x: 7, z: {}

  describe 'util.hasKeys', ->

    it 'detects whether an object has any properties', ->
      expect(util.hasKeys {}).to.be.false
      expect(util.hasKeys {a: undefined}).to.be.true
      expect(util.hasKeys {a: 1, b: {}}).to.be.true

    it 'supports an ignore option', ->
      expect(util.hasKeys {a: 2}).to.be.true
      expect(util.hasKeys {a: 2}, 'a').to.be.false
      expect(util.hasKeys {a: 2, b: 3}, 'a').to.be.true
