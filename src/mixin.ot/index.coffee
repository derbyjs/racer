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

    # Overrides STM get
    get:
      type: 'basic'
      fn: (path) ->
        if at = @_at
          path = if path then at + '.' + path else at
        val = @_adapter.get path, @_specModel()
        if val && val.$ot?
          return @_otField(path, val).snapshot
        return val

  mutators:

    insertOT:
      type: 'ot'
      fn: (path, pos, text, callback) ->
        op = [ { p: pos, i: text } ]
        @_otField(path).submitOp op, callback
        return

    delOT:
      type: 'ot'
      fn: (path, pos, len, callback) ->
        field = @_otField path
        del = field.snapshot.substr pos, len
        op = [ { p: pos, d: del } ]
        field.submitOp op, callback
        return del

  proto:
    ## OT field functions ##
    ot: (initVal) -> $ot: initVal || ''

    isOtPath: (path) ->
      @_adapter.get(path, @_specModel()).$ot isnt undefined

    isOtVal: (val) -> !!(val && val.$ot)

    _otField: (path, val) ->
      path = @dereference path
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
