Serializer = require '../Serializer'
transaction = require '../transaction'

# When parent model tries to write changes to atomic model,
# then make sure to abort atomic model if any of the changes
# modify paths.

proto = null
AtomicModel = module.exports = (id, parentModel) ->
  AtomicModel = (id, parentModel) ->
    self = this
    self.id = id
    self.parentModel = parentModel
    adapter = self._adapter = parentModel._adapter
    self.ver = adapter.version

    self._specCache =
      invalidate: ->
        delete @data
        delete @lastTxnId

    self._opCount = 0
    self._txns = parentModel._txns
    self._txnQueue = parentModel._txnQueue.slice 0

    # Proxy events to the parent model
    ['emit', 'on', 'once'].forEach (method) ->
      self[method] = ->
        parentModel[method].apply parentModel, arguments

    return

  # TODO: This prototype copying should be based on the mixins
  AtomicModel:: = proto
  parentProto = Object.getPrototypeOf parentModel
  for method in ['_addOpAsTxn', '_queueTxn', '_specModel', '_applyMutation',
  '_dereference', '_emitModelEvent', 'set', 'setNull', 'del', 'incr',
  'push', 'unshift', 'insert', 'pop', 'shift', 'insert', 'remove', 'move']
    proto[method] = parentProto[method]

  return new AtomicModel id, parentModel

proto =
  isMyOp: (id) ->
    extracted = id.substr 0, id.lastIndexOf('.')
    return extracted == @id

  oplog: ->
    modelId = @id
    txns = @_txns
    txnQueue = @_txnQueue
    return (txns[id] for id in txnQueue when @isMyOp id)

  _oplogAsTxn: ->
    ops = (transaction.op.create(
      method: transaction.method txn
      args: transaction.args txn
    ) for txn in @oplog())
    return transaction.create base: @ver, id: @id, ops: ops

  _getVer: -> @ver
  _commit: ->
  commit: (callback) ->
    txn = @_oplogAsTxn()
    @parentModel._queueTxn txn, callback
    @parentModel._commit txn

  get: (path) ->
    val = @_adapter.get path, @_specModel()
    ver = @_adapter.version
    if ver <= @ver
      @_addOpAsTxn 'get', [path]
    return val

  _nextTxnId: -> @id + '.' + ++@_opCount

  _conflictsWithMe: (txn) ->
    modelId = @id
    txns = @_txns
    txnQueue = @_txnQueue
    for id in txnQueue
      myTxn = txns[id]
      if @isMyOp id && transaction.doesSharePath(txn, myTxn) && ver < transaction.base txn
        return true
    return false
