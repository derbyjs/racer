Promise = require './Promise'

module.exports = (racer) ->
  racer.mixin mixin

mixin =
  type: "Model"

  static:
    BUNDLE_TIMEOUT: BUNDLE_TIMEOUT = 1000

  events:
    init: (model) ->
      model._bundlePromises = []
      model._onLoad = []

  server:
    bundle: (callback) ->
      # This event can be used by Model mixins to add items to onLoad before bundling
      @mixinEmit 'bundle', this
      timeout = setTimeout onBundleTimeout, BUNDLE_TIMEOUT
      Promise.parallel(@_bundlePromises).on =>
        clearTimeout timeout
        @_bundle callback

    _bundle: (callback) ->
      clientId = @_clientId
      @store._unregisterLocalModel clientId
      callback JSON.stringify [clientId, @_memory, @_count, @_onLoad, @_startId, @_ioUri]

onBundleTimeout = ->
  throw new Error "Model bundling took longer than #{BUNDLE_TIMEOUT} ms"
