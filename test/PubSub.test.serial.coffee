should = require 'should'
finishAll = false

PubSub = require 'PubSub'
pubsub = new PubSub
#pubsub.debug = true

module.exports =
  setup: (done) ->
    pubsub.flush done
  teardown: (done) ->
    if finishAll
      return pubsub.disconnect done
    pubsub.flush done

  'a published transaction to a plain path should only be received if subscribed to': (done) ->
    pubsub.onMessage = (subscriberId, message) ->
      subscriberId.should.equal '1'
      message.should.equal 'value'
      done()

    [subscriber, publisher] = ['1', '2']
    pubsub.subscribe subscriber, 'channel'
    pubsub.publish publisher, 'channel', 'value'
  
  'a published transaction to a patterned path should only be received if subscribed to': (done) ->
    pubsub.onMessage = (subscriberId, message) ->
      subscriberId.should.equal '1'
      message.should.equal 'value'
      done()

    [subscriber, publisher] = ['1', '2']
    pubsub.subscribe subscriber, 'channel.*'
    pubsub.publish publisher, 'channel.1', 'value'

  'unsubscribing from a path means the subscriber should no longer receive the path messages': (done) ->
    counter = 0
    pubsub.onMessage = (subscriberId, message) ->
      counter++
      subscriberId.should.equal '1'
      if message == 'last'
        counter.should.equal 3
        done()

    [subscriber, publisher] = ['1', '2']
    pubsub.subscribe subscriber, 'a'
    pubsub.subscribe subscriber, 'b'

    setTimeout ->
      pubsub.publish publisher, 'a', 'first'
      pubsub.publish publisher, 'b', 'second'

      setTimeout ->
        pubsub.unsubscribe subscriber, 'a'
        setTimeout ->
          pubsub.publish publisher, 'a', 'ignored'
          pubsub.publish publisher, 'b', 'last'
        , 200
      , 200
    , 200

  'unsubscribing from a path you are not subscribed to should be harmless': (done) ->
    pubsub.unsubscribe 'subcriber', 'not-subscribed-to-this-channel'
    done()

  'unsubscribing from a pattern means the subscriber should no longer receive the pattern messages': (done) ->
    counter = 0
    pubsub.onMessage = (subscriberId, message) ->
      counter++
      subscriberId.should.equal '1'
      if message == 'last'
        counter.should.equal 3
        done()

    [subscriber, publisher] = ['1', '2']
    pubsub.subscribe subscriber, 'a.*'
    pubsub.subscribe subscriber, 'b.*'

    setTimeout ->
      pubsub.publish publisher, 'a.1', 'first'
      pubsub.publish publisher, 'b.1', 'second'

      setTimeout ->
        pubsub.unsubscribe subscriber, 'a.*'
        setTimeout ->
          pubsub.publish publisher, 'a.2', 'ignored'
          pubsub.publish publisher, 'b.2', 'last'
        , 200
      , 200
    , 200

  'subscribing > 1 time to the same path should still only result in the subscriber receiving the message once': (done) ->
    counter = 0
    pubsub.onMessage = (subscriberId, message) ->
      subscriberId.should.equal '1'
      counter++
      if message == 'last'
        counter.should.equal 2
        done()

    [subscriber, publisher] = ['1', '2']
    pubsub.subscribe subscriber, 'channel'
    pubsub.subscribe subscriber, 'channel'

    pubsub.publish publisher, 'channel', 'first'
    pubsub.publish publisher, 'channel', 'last'

  'subscribing > 1 time to the same pattern should still only result in the subscriber receiving the message once': (done) ->
    counter = 0
    pubsub.onMessage = (subscriberId, message) ->
      subscriberId.should.equal '1'
      counter++
      if message == 'last'
        counter.should.equal 2
        done()

    [subscriber, publisher] = ['1', '2']
    pubsub.subscribe subscriber, 'channel.*'
    pubsub.subscribe subscriber, 'channel.*'

    pubsub.publish publisher, 'channel.1', 'first'
    pubsub.publish publisher, 'channel.1', 'last'

  'subscribing to a pattern, and then to a pattern-matching path, should still receive messages for the pattern and should only receive a given message for the path once': (done) ->
    counter = 0
    pubsub.onMessage = (subscriberId, message) ->
      subscriberId.should.equal '1'
      counter++
      if message == 'two'
        counter.should.equal 2
        done()

    [subscriber, publisher] = ['1', '2']
    pubsub.subscribe subscriber, 'channel.*'
    pubsub.subscribe subscriber, 'channel.1'

    pubsub.publish publisher, 'channel.1', 'one'
    pubsub.publish publisher, 'channel.2', 'two'

  'subscribing to a path, and then to a pattern that covers the path, should still receive messages for the path (once per given message) and should also start receiving messages for other paths covered by the pattern': (done) ->
    counter = 0
    pubsub.onMessage = (subscriberId, message) ->
      subscriberId.should.equal '1'
      counter++
      if message == 'two'
        counter.should.equal 2
        done()

    [subscriber, publisher] = ['1', '2']
    pubsub.subscribe subscriber, 'channel.1'
    pubsub.subscribe subscriber, 'channel.*'

    setTimeout ->
      pubsub.publish publisher, 'channel.1', 'one'
      pubsub.publish publisher, 'channel.2', 'two'
    , 200

  finishAll: (done) -> finishAll = true; done()

  ## !! PLACE ALL TESTS BEFORE finishAll !! ##
