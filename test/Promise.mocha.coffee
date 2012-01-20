Promise = require '../src/Promise'
should = require 'should'
{calls} = require './util'

describe 'Promise', ->

  it 'should execute immediately if the Promise is already fulfilled', (done) ->
    p = new Promise
    p.fulfill true
    p.on (val) ->
      val.should.be.true
      done()

  it 'should execute immediately using the appropriate scope if the Promise is already fulfilled', (done) ->
    p = new Promise
    p.fulfill true
    p.on (val) ->
      val.should.be.true
      @foo.should.equal 'bar'
      done()
    , foo: 'bar'

  it 'should wait to execute a callback until the Promise is fulfilled', (done) ->
    p = new Promise
    p.on (val) ->
      val.should.be.true
      done()
    p.fulfill true

  it 'should wait to execute a callback using the appropriate scope until the Promise is fulfilled', (done) ->
    p = new Promise
    p.on (val) ->
      val.should.be.true
      @foo.should.equal 'bar'
      done()
    , foo: 'bar'
    p.fulfill true

  it 'should wait to execute multiple callbacks until the Promise is fulfilled', calls 2, (done) ->
    p = new Promise
    p.on (val) ->
      val.should.be.true
      @foo.should.equal 'bar'
      done()
    , foo: 'bar'

    p.on (val) ->
      val.should.be.true
      @foo.should.equal 'fighters'
      done()
    , foo: 'fighters'

    p.fulfill true

  it 'should execute multiple callbacks immediately if the Promise is already fulfilled', calls 2, (done) ->
    p = new Promise
    p.fulfill true
    p.on (val) ->
      val.should.be.true
      @foo.should.equal 'bar'
      done()
    , foo: 'bar'

    p.on (val) ->
      val.should.be.true
      @foo.should.equal 'fighters'
      done()
    , foo: 'fighters'

  it 'should execute a callback decalared before fulfillment and then declare a subsequent callback immediately after fulfillment', calls 2, (done) ->
    p = new Promise
    p.on (val) ->
      val.should.be.true
      @foo.should.equal 'bar'
      done()
    , foo: 'bar'
    p.fulfill true
    p.on (val) ->
      val.should.be.true
      @foo.should.equal 'fighters'
      done()
    , foo: 'fighters'

  it 'clearValue should clear the fulfilled value of a Promise and invoke only new callbacks upon a subsequent fulfillment', calls 2, (done) ->
    p = new Promise
    counter = 0
    p.on (val) ->
      val.should.equal 'first'
      (++counter).should.equal 1
      done()
    p.fulfill 'first'
    p.clearValue()
    p.on (val) ->
      val.should.equal 'second'
      (++counter).should.equal 2
      done()
    p.fulfill 'second'

  it 'Promise.parallel should create a new promise that is not fulfilled until all of the component Promises are fulfilled', (done) ->
    p1 = new Promise
    p2 = new Promise
    p1Val = null
    p2Val = null
    p1.on (val) ->
      p1Val = val
    p2.on (val) ->
      p2Val = val
    p = Promise.parallel [p1, p2]
    p.on ([val1], [val2]) ->
      val1.should.eql 'hello'
      val2.should.eql 'world'
      p1Val.should.equal 'hello'
      p2Val.should.equal 'world'
      done()
    p1.fulfill 'hello'
    p2.fulfill 'world'

  it 'a promise resulting from Promise.parallel should clear its value if at least one of its component Promises clears its values', calls 2, (done) ->
    p1 = new Promise
    p2 = new Promise
    p = Promise.parallel [p1, p2]
    counter = 0
    p.on (val) ->
      val.should.equal 'first'
      (++counter).should.equal 1
      done()

    p.fulfill 'first'

    p1.clearValue()

    p.on (val) ->
      val.should.equal 'second'
      (++counter).should.equal 2
      done()

    p.fulfill 'second'
