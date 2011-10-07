Promise = require 'Promise'
should = require 'should'
{wrapTest} = require './util'

module.exports =
  'should execute immediately if the Promise is already fulfilled': wrapTest (done) ->
    p = new Promise
    p.fulfill true
    p.on (val) ->
      val.should.be.true
      done()

  '''should execute immediately using the appropriate scope
  if the Promise is already fulfilled''': wrapTest (done) ->
    p = new Promise
    p.fulfill true
    p.on (val) ->
      val.should.be.true
      @foo.should.equal 'bar'
      done()
    , foo: 'bar'

  'should wait to execute a callback until the Promise is fulfilled': wrapTest (done) ->
    p = new Promise
    p.on (val) ->
      val.should.be.true
      done()
    p.fulfill true

  '''should wait to execute a callback using the appropriate scope
  until the Promise is fulfilled''': wrapTest (done) ->
    p = new Promise
    p.on (val) ->
      val.should.be.true
      @foo.should.equal 'bar'
      done()
    , foo: 'bar'
    p.fulfill true

  '''should wait to execute multiple callbacks until the Promise is
    fulfilled''': wrapTest (done) ->
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
  , 2

  '''should execute multiple callbacks immediately if the
  Promise is already fulfilled''': wrapTest (done) ->
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
  , 2

  '''should execute a callback decalared before fulfillment
  and then declare a subsequent callback immediately
  after fulfillment''': wrapTest (done) ->
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
  , 2

  '''clearValue should clear the fulfilled value of a Promise
  and invoke only new callbacks upon a subsequent fulfillment''': wrapTest (done) ->
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
  , 2

  '''Promise.parallel should create a new promise that is not fulfilled
  until all of the component Promises are fulfilled''': wrapTest (done) ->
    p1 = new Promise
    p2 = new Promise
    p1Val = null
    p2Val = null
    p1.on (val) ->
      p1Val = val
    p2.on (val) ->
      p2Val = val
    p = Promise.parallel p1, p2
    p.on (val) ->
      val.should.be.true
      p1Val.should.equal 'hello'
      p2Val.should.equal 'world'
      done()
    p1.fulfill 'hello'
    p2.fulfill 'world'

  '''a promise resulting from Promise.parallel should clear its value
  if at least one of its component Promises clears its values''': wrapTest (done) ->
    p1 = new Promise
    p2 = new Promise
    p = Promise.parallel p1, p2
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
  , 2
