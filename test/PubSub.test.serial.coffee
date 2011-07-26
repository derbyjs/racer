should = require 'should'
finishAll = false

PubSub = require 'PubSub'
pubsub = new PubSub
#pubsub.debug = true

module.exports =
  setup: (done) ->
    pubsub._adapter.flush done
  teardown: (done) ->
    if finishAll
      return pubsub._adapter.disconnect done
    pubsub._adapter.flush done

  'a published transaction to a plain path should only be received if subscribed to': (done) ->
    pubsub.onMessage = (subscriberId, message) ->
      subscriberId.should.equal '1'
      message.should.equal 'value'
      done()

    [subscriber, publisher] = ['1', '2']
    pubsub.subscribe subscriber, ['channel']
    pubsub.publish publisher, 'channel', 'value'
  
  'a published transaction to a patterned `prefix.*` path should only be received if subscribed to': (done) ->
    pubsub.onMessage = (subscriberId, message) ->
      subscriberId.should.equal '1'
      message.should.equal 'value'
      done()

    [subscriber, publisher] = ['1', '2']
    pubsub.subscribe subscriber, ['channel.*']
    pubsub.publish publisher, 'channel.1', 'value'

  'a published transaction to a patterned `prefix.*.suffix` path should only be received if subscribed to': (done) ->
    counter = 0
    pubsub.onMessage = (subscriberId, message) ->
      counter++
      subscriberId.should.equal '1'
      message.substr(0, message.length-1).should.equal 'valueA'
      if message == 'valueA2'
        counter.should.equal 2
        done()

    [subscriber, publisher] = ['1', '2']
    pubsub.subscribe subscriber, ['channel.*.suffix']
    pubsub.publish publisher, 'channel.1.suffix', 'valueA1'
    pubsub.publish publisher, 'channel.1.nomatch', 'valueB'
    pubsub.publish publisher, 'channel.1.suffix', 'valueA2'

  'unsubscribing from a path means the subscriber should no longer receive the path messages': (done) ->
    counter = 0
    pubsub.onMessage = (subscriberId, message) ->
      counter++
      subscriberId.should.equal '1'
      if message == 'last'
        counter.should.equal 3
        done()

    [subscriber, publisher] = ['1', '2']
    pubsub.subscribe subscriber, ['a']
    pubsub.subscribe subscriber, ['b']

    setTimeout ->
      pubsub.publish publisher, 'a', 'first'
      pubsub.publish publisher, 'b', 'second'

      setTimeout ->
        pubsub.unsubscribe subscriber, ['a']
        setTimeout ->
          pubsub.publish publisher, 'a', 'ignored'
          pubsub.publish publisher, 'b', 'last'
        , 200
      , 200
    , 200

  'unsubscribing from a path you are not subscribed to should be harmless': (done) ->
    pubsub.unsubscribe 'subcriber', ['not-subscribed-to-this-channel']
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
    pubsub.subscribe subscriber, ['a.*']
    pubsub.subscribe subscriber, ['b.*']

    setTimeout ->
      pubsub.publish publisher, 'a.1', 'first'
      pubsub.publish publisher, 'b.1', 'second'

      setTimeout ->
        pubsub.unsubscribe subscriber, ['a.*']
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
    pubsub.subscribe subscriber, ['channel']
    pubsub.subscribe subscriber, ['channel']

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
    pubsub.subscribe subscriber, ['channel.*']
    pubsub.subscribe subscriber, ['channel.*']

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
    pubsub.subscribe subscriber, ['channel.*']
    pubsub.subscribe subscriber, ['channel.1']

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
    pubsub.subscribe subscriber, ['channel.1']
    pubsub.subscribe subscriber, ['channel.*']

    setTimeout ->
      pubsub.publish publisher, 'channel.1', 'one'
      pubsub.publish publisher, 'channel.2', 'two'
    , 200

  '2 subscribers to the same pattern should both receive messages': (done) ->
    counter = 2
    subscribersWithReceipt = []
    pubsub.onMessage = (subscriberId, message) ->
      message.should.equal 'value'
      subscribersWithReceipt.push subscriberId
      if subscribersWithReceipt.length ==2
        subscribersWithReceipt.should.contain subscriberOne
        subscribersWithReceipt.should.contain subscriberTwo
        done()

    [subscriberOne, subscriberTwo, publisher] = ['1', '2', '3']
    pubsub.subscribe subscriberOne, ['channel.*']
    pubsub.subscribe subscriberTwo, ['channel.*']
    pubsub.publish publisher, 'channel.1', 'value'

  'subscribedToTxn should test if a client id is subscribed to a given transaction': ->
    subscriber = '100'
    pubsub.subscribe subscriber, ['b.*']
    txnOne = [0, '1.0', 'set', 'a.b.c', 1]
    txnTwo = [0, '1.0', 'set', 'b.c', 1]
    txnThree = [0, '1.0', 'set', 'b.c.d', 1]
    pubsub.subscribedToTxn(subscriber, txnOne).should.be.false
    pubsub.subscribedToTxn(subscriber, txnTwo).should.be.true
    pubsub.subscribedToTxn(subscriber, txnThree).should.be.true

  finishAll: (done) -> finishAll = true; done()

  ## !! PLACE ALL TESTS BEFORE finishAll !! ##
