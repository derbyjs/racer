BrowserModel = require './Model'
Promise = require './Promise'

module.exports = ServerModel = ->
  @_bundlePromises = []
  @_onLoad = []
  BrowserModel.apply this, arguments
  return

ServerModel:: = Object.create BrowserModel::

ServerModel::bundle = (callback) ->
  self = this
  # This event can be used by Model mixins to add items to onLoad before bundling
  @mixinEmit 'bundle', self
  Promise.parallel(@_bundlePromises).on ->
    self._bundle callback

ServerModel::_bundle = (callback) ->
  clientId = @_clientId
  @store._unregisterLocalModel clientId
  callback JSON.stringify [clientId, @_memory, @_count, @_onLoad, @_startId, @_ioUri]
