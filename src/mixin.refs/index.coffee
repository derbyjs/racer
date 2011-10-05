RefHelper = require '../RefHelper'

module.exports =
  init: ->
    @_refHelper = refHelper = new RefHelper @

  withAccessors: (accessors, Model) ->
    Model.mixin
      init: ->
        self = this
        refHelper = @_refHelper
        for method of accessors
          continue if method is 'get'
          do (method) ->
            self._on method, ([path, args...], isLocal) ->
              # Emit events on any references that point to the path or any of its
              # ancestor paths
              refHelper.notifyPointersTo path, @get(), method, args, isLocal

  proto:
    # Create reference objects for use in model data methods
    ref: RefHelper::ref

    arrayRef: RefHelper::arrayRef
