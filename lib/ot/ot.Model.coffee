Field = require './Field'

# TODO Do JSON OT
# TODO Offline support for OT

module.exports =
  type: 'Model'

  static:
    OT_MUTATOR: OT_MUTATOR = 'mutator,otMutator'

  events:
    init: (model) ->
      model._otFields = otFields = {}

      model.on 'addSubData', (data) ->
        if ot = data.ot
          otFields[path] = field  for path, field of ot
      return

    bundle: (model) ->
      # TODO: toJSON shouldn't be called manually like this
      fields = {}
      for path, field of model._otFields
        # OT objects aren't serializable until after one or more OT operations
        # have occured on that object
        fields[path] = field.toJSON()  if field.toJSON
      model._onLoad.push ['_loadOt', fields]

    socket: (model, socket) ->
      otFields = model._otFields
      memory = model._memory
      socket.on 'otOp', ({path, op, v}) ->
        unless field = otFields[path]
          field = otFields[path] = new Field model, path
          field.specTrigger().on ->
            val = memory.get path, model._specModel()
            field.snapshot = val?.$ot || ''
            field.onRemoteOp op, v
        else
          field.onRemoteOp op, v

  proto:

    # TODO: Don't override standard get like this
    get:
      type: 'accessor'
      fn: (path) ->
        if at = @_at
          path = if path then at + '.' + path else at
        val = @_memory.get path, @_specModel()
        if val && val.$ot?
          return @_otField(path, val).snapshot
        return val

    otInsert:
      type: OT_MUTATOR
      fn: (path, pos, text, callback) ->
        op = [ { p: pos, i: text } ]
        @_otField(path).submitOp op, callback
        return

    otDel:
      type: OT_MUTATOR
      fn: (path, pos, len, callback) ->
        field = @_otField path
        del = field.snapshot.substr pos, len
        op = [ { p: pos, d: del } ]
        field.submitOp op, callback
        return del

    ot: (path, value, callback) ->
      if at = @_at
        len = arguments.length
        path = if len is 1 || len is 2 && typeof value is 'function'
          callback = value
          value = path
          at
        else
          at + '.' + path

      finish = (err, path, value, previous) =>
        if !err && field = @_otFields[path]
          field.specTrigger true
        callback? err, path, value, previous

      return @_sendToMiddleware 'set', [path, $ot: value], finish

    otNull: (path, value, callback) ->
      len = arguments.length
      obj = if @_at && len is 1 || len is 2 && typeof value is 'function'
        @get()
      else
        @get path
      return obj  if obj?

      return if len is 1
        @ot path
      else if len is 2
        @ot path, value
      else
        @ot path, value, callback

    isOtPath: (path, nonSpeculative) ->
      data = if nonSpeculative then null else @_specModel()
      return @_memory.get(path, data)?.$ot?

    isOtVal: (val) -> !!(val && val.$ot)

    _otField: (path, val) ->
      path = @dereference path
      return field if field = @_otFields[path]

      field = @_otFields[path] = new Field this, path
      val ||= @_memory.get path, @_specModel()
      field.snapshot = val && val.$ot || ''
      # TODO field.remoteSnapshot snapshot
      return field

    _loadOt: (fields) ->
      for path, json of fields
        @_otFields[path] = Field.fromJSON json, this
