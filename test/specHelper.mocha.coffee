should = require 'should'
{createObject, createArray, create, isSpeculative} = require '../src/specHelper'

describe 'specHelper', ->

  it 'test create with object', ->
    proto = hey: 'Howdy!'
    obj = create proto
    isSpeculative(obj).should.eql true
    obj.should.specEql hey: 'Howdy!'
    proto.should.eql hey: 'Howdy!'

    obj.more = 5
    isSpeculative(obj).should.eql true
    obj.should.specEql hey: 'Howdy!', more: 5
    proto.should.eql hey: 'Howdy!'

  it 'test createObject', ->
    obj = createObject()
    isSpeculative(obj).should.eql true
    obj.should.specEql {}

    obj.more = 5
    isSpeculative(obj).should.eql true
    obj.should.specEql more: 5

  it 'test create with array', ->
    proto = [0, 'stuff']
    arr = create proto
    isSpeculative(arr).should.eql true
    Array.isArray(arr).should.eql true
    arr.should.specEql [0, 'stuff']
    arr.length.should.eql 2
    proto.should.eql [0, 'stuff']

    arr.push 7
    isSpeculative(arr).should.eql true
    Array.isArray(arr).should.eql true
    arr.should.specEql [0, 'stuff', 7]
    arr.length.should.eql 3
    proto.should.eql [0, 'stuff']

    arr.length = 1
    isSpeculative(arr).should.eql true
    Array.isArray(arr).should.eql true
    arr.should.specEql [0]
    proto.should.eql [0, 'stuff']

  it 'test createArray', ->
    arr = createArray()
    isSpeculative(arr).should.eql true
    Array.isArray(arr).should.eql true
    arr.should.specEql []
    arr.length.should.eql 0

    arr.push 2, 7
    isSpeculative(arr).should.eql true
    Array.isArray(arr).should.eql true
    arr.should.specEql [2, 7]
    arr.length.should.eql 2

    arr.length = 1
    isSpeculative(arr).should.eql true
    Array.isArray(arr).should.eql true
    arr.should.specEql [2]
