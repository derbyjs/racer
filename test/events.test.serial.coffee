events = require '../src/events'
Subscription = events.Subscription
should = require 'should'

_ =
  extend: (a, b) ->
    a[k] = v for k, v of b

module.exports =
  'listeners should respond to events': (done) ->
    emitter = {}
    _.extend emitter, events
    emitter.on 'ev', -> done()
    emitter.trigger 'ev'
  'listeners should be able to have a context': (done) ->
    emitter = {}
    ctx = answer: 'correct'
    _.extend emitter, events
    emitter.on 'ev', () ->
      @answer.should.equal ctx.answer
      done()
    , ctx
    emitter.trigger 'ev'
  'should be able to pass arguments to a listener via `trigger`': (done) ->
    emitter = {}
    _.extend emitter, events
    emitter.on 'ev', (a, b, c) ->
      a.should.equal 'a'
      b.should.equal 'b'
      c.should.equal 'c'
      done()
    emitter.trigger 'ev', 'a', 'b', 'c'
  'adding a listener should return a cancelable subscription': (done) ->
    emitter = {}
    _.extend emitter, events
    subsc = emitter.on 'ev', ->
    subsc.should.be.an.instanceof Subscription
    done()
  'a return listener subscription should remove itself from the set of listeners when it cancels': (done) ->
    emitter = {}
    flag = 0
    _.extend emitter, events
    subsc = emitter.on 'ev', -> flag++
    subsc.cancel()
    emitter.trigger 'ev'
    setTimeout ->
      flag.should.equal 0
      done()
    , 200
  'a subscription should be active until canceled': (done) ->
    emitter = {}
    _.extend emitter, events
    subsc = emitter.on 'ev', -> subsc.active.should.be.true
    emitter.trigger 'ev'
    subsc.active.should.be.true
    subsc.cancel()
    subsc.active.should.be.false
    done()
  'canceling a subscription should not cancel other subscriptions': (done) ->
    emitter = {}
    flag = 0
    _.extend emitter, events
    subsc1 = emitter.on 'ev', -> flag++
    subsc2 = emitter.on 'ev', -> flag += 2
    subsc1.cancel()
    emitter.trigger 'ev'
    flag.should.equal 2
    subsc1.active.should.be.false
    subsc2.active.should.be.true
    done()
  'listeners should respond to events more than once': (done) ->
    times = 2
    emitter = {}
    flag = 0
    _.extend emitter, events
    emitter.on 'ev1', -> flag++
    emitter.trigger 'ev1' while (times--)
    flag.should.equal 2
    done()
  'adding a once listener should return a cancelable subscription': (done) ->
    emitter = {}
    _.extend emitter, events
    subsc = emitter.once 'ev', ->
    subsc.should.be.an.instanceof Subscription
    done()
  'a once listener should only respond to an event only once': (done) ->
    times = 2
    emitter = {}
    flag = 0
    _.extend emitter, events
    emitter.once 'ev1', () -> flag++
    emitter.trigger 'ev1' while (times--)
    flag.should.equal 1
    done()
  'a once listener should respect any bound contexts': (done) ->
    emitter = {}
    ctx = { name: 'lynn' }
    _.extend(emitter, events)
    emitter.once 'ev', ->
      @name.should.equal ctx.name
      done()
    , ctx
    emitter.trigger 'ev'
  'after a once listener executes, its state should be inactive': (done) ->
    emitter = {}
    _.extend emitter, events
    subsc = emitter.once 'ev', ->
    subsc.active.should.be.true
    emitter.trigger 'ev'
    subsc.active.should.be.false
    done()
  'trigger should be able to mute the event to a single listener': (done) ->
    emitter = {}
    flag = 0
    _.extend emitter, events
    y = emitter.on 'ev', -> flag++
    z = emitter.on 'ev', -> flag++
    emitter.trigger 'ev', 1, mute: y
    flag.should.equal 1
    done()
  'trigger should be able to mute the event to multiple listeners': (done) ->
    emitter = {}
    flag = 0
    _.extend emitter, events
    y = emitter.on 'ev', -> flag++
    z = emitter.on 'ev', (a) -> flag++
    emitter.trigger 'ev', 1, mute: [y,z]
    flag.should.equal 0
    done()
