{expect} = require '../util'
util = require '../../lib/util'

describe 'util', ->

  describe 'util.mergeInto', ->

    it 'merges empty objects', ->
      a = {}
      b = {}
      expect(util.mergeInto a, b).to.eql {}

    it 'merges an empty object with a populated object', ->
      fn = (x) -> x++
      a = {}
      b = x: 's', y: [1, 3], fn: fn
      expect(util.mergeInto a, b).to.eql x: 's', y: [1, 3], fn: fn

    it 'merges a populated object with a populated object', ->
      fn = (x) -> x++
      a = x: 's', y: [1, 3], fn: fn
      b = x: 7, z: {}
      expect(util.mergeInto a, b).to.eql x: 7, y: [1, 3], fn: fn, z: {}

      # Merge should modify the first argument
      expect(a).to.eql x: 7, y: [1, 3], fn: fn, z: {}
      # But not the second
      expect(b).to.eql x: 7, z: {}
