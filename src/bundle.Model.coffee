Promise = require './Promise'

module.exports = (racer) ->
  racer.mixin mixin

mixin =
  type: "Model"

  events:
    init: (model) ->
      model._bundlePromises = []
      model._onLoad = []

  server:
    bundle: (callback) ->
      self = this
      # This event can be used by Model mixins to add items to onLoad before bundling
      @mixinEmit 'bundle', self
      Promise.parallel(@_bundlePromises).on ->
        self._bundle callback

    _bundle: (callback) ->
      clientId = @_clientId
      @store._unregisterLocalModel clientId
      callback JSON.stringify [clientId, @_memory, @_count, @_onLoad, @_startId, @_ioUri]
