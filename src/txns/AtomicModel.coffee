{EventEmitter} = require 'events'
Serializer = require '../Serializer'
transaction = require '../transaction'
{mergeAll} = require '../util'

# When parent model tries to write changes to atomic model,
# then make sure to abort atomic model if any of the changes
# modify paths.

module.exports = (id, parentModel) ->

  AtomicModel = (id, parentModel) ->
    @id = id
    @parentModel = parentModel
    @_memory = memory = parentModel._memory
    @version = memory.version

    @_specCache =
      invalidate: ->
        delete @data
        delete @lastTxnId

    @_opCount = 0
    @_txns = parentModel._txns
    @_txnQueue = parentModel._txnQueue.slice 0

    # Proxy events to the parent model
    for method of EventEmitter::
      do (method) =>
        @[method] = -> parentModel[method].apply parentModel, arguments

    return

  mergeAll AtomicModel::, Object.getPrototypeOf(parentModel), proto

  return new AtomicModel id, parentModel

proto =
  isMyOp: (id) ->
    extracted = id.substr 0, id.lastIndexOf('.')
    return extracted == @id

  oplog: ->
    txns = @_txns
    txnQueue = @_txnQueue
    return (txns[id] for id in txnQueue when @isMyOp id)

  _oplogAsTxn: ->
    ops = for txn in @oplog()
      transaction.op.create
        method: transaction.getMethod txn
        args: transaction.getArgs txn
    return transaction.create ver: @version, id: @id, ops: ops

  _getVersion: -> @version

  commit: (callback) ->
    txn = @_oplogAsTxn()
    @parentModel._queueTxn txn, callback
    @parentModel._commit txn

  get: (path) ->
    val = @_memory.get path, @_specModel()
    ver = @_memory.version
    if ver <= @version
      @_addOpAsTxn 'get', [path]
    return val

  _nextTxnId: -> @id + '.' + (++@_opCount)

  _conflictsWithMe: (txn) ->
    txns = @_txns
    ver = @version
    for id in @_txnQueue
      myTxn = txns[id]
      if @isMyOp(id) && transaction.pathConflict(txn, myTxn) && ver < transaction.getVer(txn)
        return true
    return false
