text = require 'share/lib/types/text'
syncqueue = requre 'share/lib/server/syncqueue'

# DB needs to keep around
# data: {type, v, snapshot, meta}
# ops: [op]

Field = module.exports = (@adapter, @path, @version, @type = text) ->
  @queue = syncqueue ({op, v, meta}, callback) =>
    @getSnapshot (docData) ->
      return callback new Error 'Document does not exist' unless docData



Field ::=
  getSnapshot: (callback) ->
    # TODO Separate adapter.get version return (which is really for stm purposes) from adapter.get for use with OT (See adapters/Memory)
    @adapter.get 'ot.' + @path, (err, val, ver) ->

  applyOp: (op, callback) ->
    


  otApply: ({op, v}, callback) ->
    res = {op, v}
    res.meta ||= {}
    #TODO Define socket
    res.meta.src = socket.id
