# TODO Do JSON OT
# TODO Work on offline support for OT

Field = require './Field'

# TODO Decorate adapter?

ot = module.exports =
  init: ->
    @otFields = {}

    @on 'setPost', ([path, value], ver) ->
      # ver will be null for speculative values, so this detects
      # when the OT path has been created on the server
      if ver && value && value.$ot
        @_otField(path).specTrigger true

  accessors:
    # OT text insert
    insertOT: (path, str, pos, callback) ->
      # TODO: Cleanup refs dependency
      op = [ { p: pos || 0, i: str } ]
      @_otField(path).submitOp op, callback

    # OT text del
    delOT: (path, len, pos, callback) ->
      field = @_otField path
      op = [ { p: pos, d: field.snapshot[pos...pos+len] } ]
      field.submitOp op, callback

  proto:
    ## OT field functions ##
    # model.ot initStr
    ot: (initVal) -> $ot: initVal

    isOtPath: (path) ->
      @_adapter.get(path, @_specModel()).$ot isnt undefined

    isOtVal: (val) -> !!(val && val.$ot)

    get: (path) ->
      val = @_adapter.get path, @_specModel()
      if val && val.$ot
        return @_otField(path, val).snapshot
      return val

    version: (path) -> @otFields[path].version

    _otField: (path, val) ->
      path = @_dereference path
      return field if field = @otFields[path]
      field = @otFields[path] = new Field this, path
      val ||= @_adapter.get path, @_specModel()
      field.snapshot = val && val.$ot || ''
      # TODO field.remoteSnapshot snapshot
      return field
  

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
          val = adapter.get path, model._specModel()
          field.snapshot = val?.$ot || ''
          field.onRemoteOp op, v
      else
        field.onRemoteOp op, v
