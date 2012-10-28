Field = require './Field.server'

# TODO: OT Shouldn't be storing stuff on a store instance
# Rewrite OT to use the journal or create a separate OT journal

module.exports =
  type: 'Store'

  events:
    init: (store) ->
      # Maps path -> { listener: fn, queue: [msg], busy: bool }
      # TODO: This shouldn't be local to a store
      store._otFields = otFields = {}

      store._pubSub.on 'ot', (clientId, data) ->
        if socket = store._clientSockets[clientId]
          return if socket.id == data.meta.src
          socket.emit 'otOp', data

      # TODO Convert the following to work beyond local memory
      store.on 'fetch', (out) ->
        otPaths = []
        for [root, value] in out.data
          allOtPaths value, root, otPaths
        return unless otPaths.length
        out.ot = otData = {}
        for otPath in otPaths
          otData[otPath] = otField  if otField = otFields[otPath]
        return

    socket: (store, socket) ->
      otFields = store._otFields
      db = store._db

      socket.on 'otOp', (msg, fn) ->
        {path, op, v} = msg

        flushViaFieldClient = ->
          unless fieldClient = field.client socket.id
            fieldClient = field.registerSocket socket
            # TODO Cleanup with field.unregisterSocket
          fieldClient.queue.push [msg, fn]
          fieldClient.flush()

        # Lazy create the OT doc
        unless field = otFields[path]
          field = otFields[path] = new Field store, path, v
          # TODO Replace with sendToDb
          db.get path, (err, val, ver) ->
            # Lazy snapshot initialization
            snapshot = field.snapshot = val?.$ot || ''
            flushViaFieldClient()
        else
          flushViaFieldClient()


allOtPaths = (obj, root, results) ->
  if obj && obj.$ot
    results.push root
    return
  return unless typeof obj is 'object'
  for key, value of obj
    continue unless value
    if value.$ot
      results.push root + '.' + key
      continue
    allOtPaths value, key
  return
