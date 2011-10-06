# TODO Do JSON OT
# TODO Work on offline support for OT

Field = require './Field'

# TODO Decorate adapter?

ot = module.exports =
  init: ->
    @otFields = {}

  accessors:
    # OT text insert
    insertOT: (path, str, pos, callback) ->
      path = @_refHelper.dereferencedPath path, @_specModel()[0]
      # TODO DRY this unless block up. Also appears in mixin.stm
      unless field = @otFields[path]
        field = @otFields[path] = new Field @, path
        {val} = @_adapter.get path, @_specModel()[0]
        snapshot = field.snapshot = val?.$ot || str
        # TODO field.remoteSnapshot snapshot
      pos ?= 0
      op = [ { p: pos, i: str } ]
      field.submitOp op, callback

    # OT text del
    delOT: (path, len, pos, callback) ->
      path = @_refHelper.dereferencedPath path, @_specModel()[0]
      unless field = @otFields[path]
        field = @otFields[path] = new Field @, path
        {val} = @_adapter.get path, @_specModel()[0]
        snapshot = field.snapshot = val?.$ot || str
        # TODO field.remoteSnapshot snapshot
      op = [ { p: pos, d: field.snapshot[pos...pos+len] } ]
      field.submitOp op, callback

  proto:
    ## OT field functions ##
    # model.ot initStr
    ot: (initVal) -> $ot: initVal

    isOtPath: (path) ->
      {val} = @_adapter.get path, @_specModel()[0]
      return val.$ot isnt undefined

    isOtVal: (val) -> return !! (val && val.$ot)

    getOT: (path, initVal) ->
      path = @_refHelper.dereferencedPath path, @_specModel()[0]
      return field.snapshot if field = @otFields[path]
      field = @otFields[path] = new Field @, path
      return field.snapshot = initVal

    version: (path) -> @otFields[path].version
  

  # Socket setup
  setupSocket: (socket) ->
    otFields = @otFields
    adapter = @_adapter
    model = this
    # OT callbacks
    socket.on 'otOp', ({path, op, v}) ->
      unless field = otFields[path]
        field = otFields[path] = new Field model, path
        field.specTrigger().on ->
          {val} = adapter.get path, model._specModel()[0]
          field.snapshot = val?.$ot || ''
          field.onRemoteOp op, v
      else
        field.onRemoteOp op, v
