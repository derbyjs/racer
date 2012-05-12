{expect} = require './util'
{createObject, createArray, create, isSpeculative} = require '../lib/util/speculative'

describe 'speculative', ->

  it 'test create with object', ->
    proto = hey: 'Howdy!'
    obj = create proto
    expect(isSpeculative obj).to.eql true
    expect(obj).to.specEql hey: 'Howdy!'
    expect(proto).to.eql hey: 'Howdy!'

    obj.more = 5
    expect(isSpeculative obj).to.eql true
    expect(obj).to.specEql hey: 'Howdy!', more: 5
    expect(proto).to.eql hey: 'Howdy!'

  it 'test createObject', ->
    obj = createObject()
    expect(isSpeculative obj).to.eql true
    expect(obj).to.specEql {}

    obj.more = 5
    expect(isSpeculative obj).to.eql true
    expect(obj).to.specEql more: 5

  it 'test create with array', ->
    proto = [0, 'stuff']
    arr = create proto
    expect(isSpeculative arr).to.eql true
    expect(Array.isArray arr).to.eql true
    expect(arr).to.specEql [0, 'stuff']
    expect(arr.length).to.eql 2
    expect(proto).to.eql [0, 'stuff']

    arr.push 7
    expect(isSpeculative arr).to.eql true
    expect(Array.isArray arr).to.eql true
    expect(arr).to.specEql [0, 'stuff', 7]
    expect(arr.length).to.eql 3
    expect(proto).to.eql [0, 'stuff']

    arr.length = 1
    expect(isSpeculative arr).to.eql true
    expect(Array.isArray arr).to.eql true
    expect(arr).to.specEql [0]
    expect(proto).to.eql [0, 'stuff']

  it 'test createArray', ->
    arr = createArray()
    expect(isSpeculative arr).to.eql true
    expect(Array.isArray arr).to.eql true
    expect(arr).to.specEql []
    expect(arr.length).to.eql 0

    arr.push 2, 7
    expect(isSpeculative arr).to.eql true
    expect(Array.isArray arr).to.eql true
    expect(arr).to.specEql [2, 7]
    expect(arr.length).to.eql 2

    arr.length = 1
    expect(isSpeculative arr).to.eql true
    expect(Array.isArray arr).to.eql true
    expect(arr).to.specEql [2]
