Promise = require './util/Promise'

exports = module.exports = (racer) ->
  BUNDLE_TIMEOUT = racer.get('bundle timeout') || racer.set('bundle timeout', 1000)
  mixin.static = {BUNDLE_TIMEOUT}
  racer.mixin mixin

exports.useWith = server: true, browser: true

mixin =
  type: "Model"

  events:
    init: (model) ->
      model._bundlePromises = []
      model._onLoad = []

  server:
    bundle: (callback) ->
      # This event can be used by Model mixins to add items to onLoad before bundling
      @mixinEmit 'bundle', this
      timeout = setTimeout onBundleTimeout, mixin.static.BUNDLE_TIMEOUT
      Promise.parallel(@_bundlePromises).on =>
        clearTimeout timeout
        @_bundle callback

    _bundle: (callback) ->
      callback JSON.stringify [@_clientId, @_memory, @_count, @_onLoad, @_startId, @_ioUri]

onBundleTimeout = ->
  throw new Error "Model bundling took longer than #{mixin.static.BUNDLE_TIMEOUT} ms"
