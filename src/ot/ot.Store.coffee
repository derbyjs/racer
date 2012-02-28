Field = require './Field.server'

# TODO: OT Shouldn't be storing stuff on a store instance
# Rewrite OT to use the journal

module.exports =
  type: 'Store'

  events:
    init: (store) ->
      # Maps path -> { listener: fn, queue: [msg], busy: bool }
      # TODO: This shouldn't be local to a store
      store._otFields = {}

    socket: (store, socket) ->
      otFields = store._otFields
      db = store._db

      # Handling OT messages
      socket.on 'otSnapshot', (setNull, fn) ->
        # Lazy create/snapshot the OT doc
        if field = otFields[path]
          # TODO
          TODO = 'TODO'

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
          field = otFields[path] =
            new Field self, pubSub, path, v
          # TODO Replace with sendToDb
          db.get path, (err, val, ver) ->
            # Lazy snapshot initialization
            snapshot = field.snapshot = val?.$ot || ''
            flushViaFieldClient()
        else
          flushViaFieldClient()

  proto:
    _onOtMsg: (clientId, ot) ->
      if socket = @_clientSockets[clientId]
        return if socket.id == ot.meta.src
        socket.emit 'otOp', ot
