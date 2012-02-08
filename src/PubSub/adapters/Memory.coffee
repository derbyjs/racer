module.exports = MemoryAdapter = (options = {}) ->
  return

# new PubSub
#   store: store
#   onMessage: (clientId, txn) ->
#   adapter: new MemoryAdapter
MemoryAdapter:: =
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

isPattern = (path) ->
  /\*/.test path
