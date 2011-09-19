Model = require './Model'
TxnApplier = require './TxnApplier'
RefHelper = require './RefHelper'
transaction = require './transaction'

# When parent model tries to write changes to atomic model,
# then make sure to abort atomic model if any of the changes
# modify paths.

AtomicModel = module.exports = (id, parentModel) ->
  self = this
  self.id = id
  adapter = self._adapter = parentModel._adapter
  self.ver = adapter.ver # Take a snapshot of the version

  self._cache = parentModel._cache

  self._opCount = 0
  self._txns = parentModel._txns
  self._txnQueue = parentModel._txnQueue.slice 0

  # TODO Do we even need a txnApplier in this scenario?
  txnApplier = new TxnApplier
    applyTxn: (txn) ->
      if self._conflictsWithMe txn
        self.abort()
      self._applyTxn txn # TODO Needs the same conds as Model txnApplier?

  onTxn = self._onTxn = (txn, num) ->
    txnApplier.add txn, num
  #parentChannel.on 'txn', onTxn

  self._refHelper = new RefHelper self

  return

AtomicModel:: =
  isMyOp: (id) ->
    extracted = id.substr 0, id.lastIndexOf('.')
    return extracted == @id

  oplog: ->
    modelId = @id
    txns = @_txns
    txnQueue = @_txnQueue
    return (txns[id] for id in txnQueue when @isMyOp id)

  get: (path) ->
    {val, ver} = @_adapter.get path, @_specModel()[0]
    if ver <= @ver
      @_addOpTxn 'get', path
    return val

  set: (path, value, callback) ->
    @_validateAtomic path
    @_addOp 'set', path, value, callback


  _nextTxnId: -> @id + '.' + ++@_opCount

  _addOpTxn: (method, path, args...) ->
    # TODO figure out how to re-use most of Model::_addOpTxn
    refHelper = @_refHelper

    ver = @ver
    id = @_nextTxnId()
    txn = transaction.create base: ver, id: id, method: method, args: [path, args...]
    txn = refHelper.dereferenceTxn txn, @_specModel()[0]
    @_txns[id] = txn
    @_txnQueue.push id

  _specModel: Model::_specModel

  _conflictsWithMe: (txn) ->
    modelId = @id
    txns = @_txns
    txnQueue = @_txnQueue
    for id in txnQueue
      myTxn = txns[id]
      if @isMyOp id && transaction.doesSharePath(txn, myTxn) && ver < transaction.base txn
        return true
    return false
