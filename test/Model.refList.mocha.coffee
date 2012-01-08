Model = require '../src/Model'
should = require 'should'
{calls} = require './util'

describe 'Model.refList', ->

  it 'should support getting', ->
    model = new Model
    model.set 'items',
      1: 'a'
      2: 'b'
      3: 'c'
    model.set 'map', [3, 1]
    model.refList 'list', 'items', 'map'

    model.get('list').should.eql ['c', 'a']
    model.get('list.0').should.eql 'c'

    # Test changing the key object
    model.set 'map', ['1', '2']
    model.get('list').should.eql ['a', 'b']

    # Test changing referenced objects
    model.set 'items',
      1: {x: 'a'}
      2: {y: 'b'}
      3: {z: 'c'}
    model.get('list').should.eql [{x: 'a'}, {y: 'b'}]

  it 'should support setting!', ->
    model = new Model
    model.refList 'list', 'items', 'map'
    model.set 'items',
      1: 'a'
      2: 'b'
      3: 'c'
    model.set 'list.0', 'c'
    model.set 'list.1', 'a'
    # model.push 'list', 'c'
    console.log model.get()
    model.get('map').should.specEql [3, 1]


    # # Setting a reference before a key should make a record of the key but
    # # not the reference
    # model.set 'mine', model.arrayRef 'todos', '_mine'
    # model.get().should.specEql
    #   mine: model.arrayRef 'todos', '_mine'
    #   _mine: []
    #   $keys: { _mine: $: mine: ['todos', '_mine', 'array'] }

    # # Setting a key value should update the reference
    # model.set '_mine', ['1', '3']
    # model.get().should.specEql
    #   mine: model.arrayRef 'todos', '_mine'
    #   _mine: ['1', '3']
    #   $keys: { _mine: $: mine: ['todos', '_mine', 'array'] }
    #   $refs:
    #     todos:
    #       1: { $: mine: ['todos', '_mine', 'array'] }
    #       3: { $: mine: ['todos', '_mine', 'array'] }