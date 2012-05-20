Promise = require './util/Promise'

exports = module.exports = (racer) ->
  BUNDLE_TIMEOUT = racer.get('bundle timeout') || racer.set('bundle timeout', 1000)
  mixin.static = {BUNDLE_TIMEOUT}
  racer.mixin mixin

exports.useWith = server: true, browser: true
exports.decorate = 'racer'

mixin =
  type: "Model"

  events:
    init: (model) ->
      model._bundlePromises = []
      model._onLoad = []

  server:
    # What the end-developer calls on the server to bundle the app up to send
    # with a response.
    bundle: (cb) ->
      # This event can be used by Model mixins to add items to onLoad before bundling
      addToBundle = (key) =>
        @_onLoad.push Array.prototype.slice.call arguments
      # TODO Only pass addToBundle to the event handlers
      @mixinEmit 'bundle', this, addToBundle
      timeout = setTimeout onBundleTimeout, mixin.static.BUNDLE_TIMEOUT
      Promise.parallel(@_bundlePromises).on =>
        clearTimeout timeout
        @_bundle cb

    _bundle: (cb) ->
      cb JSON.stringify [@_clientId, @_memory, @_count, @_onLoad, @_startId, @_ioUri]

onBundleTimeout = ->
  throw new Error "Model bundling took longer than #{mixin.static.BUNDLE_TIMEOUT} ms"
