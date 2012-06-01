{expect, calls} = require './util'
Promise = require '../lib/util/Promise'

describe 'Promise', ->

  it 'should execute immediately if the Promise is already resolved', (done) ->
    p = new Promise
    p.resolve true
    p.on (val) ->
      expect(val).to.be.true
      done()

  it 'should wait to execute a callback until the Promise is resolved', (done) ->
    p = new Promise
    p.on (val) ->
      expect(val).to.be.true
      done()
    p.resolve true

  it 'should wait to execute multiple callbacks until the Promise is resolved', calls 2, (done) ->
    p = new Promise
    p.on (val) ->
      expect(val).to.be.true
      done()
    p.on (val) ->
      expect(val).to.be.true
      done()
    p.resolve true

  it 'should execute multiple callbacks immediately if the Promise is already resolved', calls 2, (done) ->
    p = new Promise
    p.resolve true
    p.on (val) ->
      expect(val).to.be.true
      done()
    p.on (val) ->
      expect(val).to.be.true
      done()

  it 'should execute a callback decalared before resolving and then declare a subsequent callback immediately after resolving', calls 2, (done) ->
    p = new Promise
    p.on (val) ->
      expect(val).to.be.true
      done()
    p.resolve true
    p.on (val) ->
      expect(val).to.be.true
      done()

  it 'clear should clear the resolved value of a Promise and invoke only new callbacks upon a subsequent resolvement', calls 2, (done) ->
    p = new Promise
    counter = 0
    p.on (val) ->
      expect(val).to.equal 'first'
      expect(++counter).to.equal 1
      done()
    p.resolve 'first'
    p.clear()
    p.on (val) ->
      expect(val).to.equal 'second'
      expect(++counter).to.equal 2
      done()
    p.resolve 'second'

  it 'Promise.parallel should create a new promise that is not resolved until all of the component Promises are resolved', (done) ->
    p1 = new Promise
    p2 = new Promise
    p1Val = p2Val = null
    p1.on (err, val) -> p1Val = val
    p2.on (err, val) -> p2Val = val
    p = Promise.parallel([p1, p2]).on (err, values) ->
      expect(p1Val).to.eql 'hello'
      expect(p2Val).to.eql 'world'
      expect(values).to.eql ['hello', 'world']
      done()
    p1.resolve null, 'hello'
    p2.resolve null, 'world'
