# TODO Finish implementation

module.exports = (racer) ->
  racer.adapters.pubSub.Memory = PubSubMemory

PubSubMemory = ->
  return

PubSubMemory:: =
  subscribe: (subscriberId, paths, callback) ->
    channels = @_channels
    for path in paths
      subscription = channels[path] = {}
      subscription[subscriberId] = callback

  publish: (path, message) ->
    subscribers = @_channels[path]
    for subscriberId, callback of subscribers
      callback

  unsubscribe: (subscriberId, paths, callback) ->

  hasSubscriptions: (subscriberId) ->

  subscribedToTxn: (subscriberId, txn) ->

isPattern = (path) -> /\*/.test path
