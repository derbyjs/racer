should = require 'should'
finishAll = false

PubSub = require 'PubSub'
pubsub = new PubSub

# TODO
module.exports =
  setup: (done) ->
    _publishClient = pubsub._adapter._publishClient
    _publishClient.flushdb done
  teardown: (done) ->
    {_subscribeClient, _publishClient} = pubsub._adapter
    if finishAll
      _subscribeClient.end()
      _publishClient.end()
      return done()
    _publishClient.flushdb done

#  'should throw an error if pubsub.onMessage is undefined': (done) ->
#    pubsub.publish
  'a published transaction to a plain path should only be received if subscribed to': (done) ->
    pubsub.onMessage = (subscriberId, message) ->
      subscriberId.should.equal '1'
      message.should.equal 'value'
      done()

    pubsub.subscribe subscriberId='1', 'channel'
    pubsub.publish publisherId='2', 'channel', 'value'
  
  'a published transaction to a patterned path should only be received if subscribed to': (done) ->
    pubsub.onMessage = (subscriberId, message) ->
      subscriberId.should.equal '1'
      message.should.equal 'value'
      done()

    pubsub.subscribe subscriberId='1', 'channel.*'
    pubsub.publish publisherId='2', 'channel.1', 'value'

  finishAll: (done) -> finishAll = true; done()

  ## !! PLACE ALL TESTS BEFORE finishAll !! ##
