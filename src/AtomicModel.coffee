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
  self.parentModel = parentModel
  adapter = self._adapter = parentModel._adapter
  self.ver = adapter.ver # Take a snapshot of the version

  self._cache =
    invalidateSpecModelCache: ->
      delete @obj
      delete @lastReplayedTxnId
      delete @path

  self._opCount = 0
  self._txns = parentModel._txns
  self._txnQueue = parentModel._txnQueue.slice 0

#  # TODO Do we even need a txnApplier in this scenario?
#  txnApplier = new TxnApplier
#    applyTxn: (txn) ->
#      if self._conflictsWithMe txn
#        self.abort()
#      self._applyTxn txn # TODO Needs the same conds as Model txnApplier?
#
#  onTxn = self._onTxn = (txn, num) ->
#    txnApplier.add txn, num

  # parentRepo.on 'txn', onTxn
  # childRepos.send 'txn', onTxn

  # parentChannel.on 'txn', onTxn

  self._refHelper = new RefHelper self, false

  # Proxy events to the parent model
  ['emit', 'on', 'once'].forEach (method) ->
    self[method] = ->
      parentModel[method].apply parentModel, arguments

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

  _oplogAsTxn: ->
    ops = (transaction.op.create(
      method: transaction.method txn
      args: transaction.args txn
      meta: transaction.meta txn
    ) for txn in @oplog())
    return transaction.create base: @ver, id: @id, ops: ops

  commit: (callback) ->
    txn = @_oplogAsTxn()
    @parentModel._queueTxn txn, callback
    @parentModel._commit txn

  get: (path) ->
    if path
      {val, ver} = @_adapter.get path, @_specModel()[0]
    else
      val = @_specModel()[0]
      ver = @_adapter.ver
    if ver <= @ver
      @_addOpAsTxn 'get', path ? null
    return val

  set: (path, val) ->
    @_addOpAsTxn 'set', path, val
    return val

  setNull: (path, val) ->
    obj = @get path
    return obj if `obj != null`
    @set path, val

  del: (path) ->
    @_addOpAsTxn 'del', path

  push: (path, values...) ->
    @_addOpAsTxn 'push', path, values...

  pop: (path) ->
    @_addOpAsTxn 'pop', path

  unshift: (path, values...) ->
    @_addOpAsTxn 'unshift', path, values...

  shift: (path) ->
    @_addOpAsTxn 'shift', path

  insertAfter: (path, afterIndex, val) ->
    @_addOpAsTxn 'insertAfter', path, afterIndex, val

  insertBefore: (path, beforeIndex, val) ->
    @_addOpAsTxn 'insertBefore', path, beforeIndex, val

  remove: (path, start, howMany = 1) ->
    @_addOpAsTxn 'remove', path, start, howMany

  splice: (path, startIndex, removeCount, newMembers...) ->
    @_addOpAsTxn 'splice', path, startIndex, removeCount, newMembers...

  move: (path, from, to) ->
    @_addOpAsTxn 'move', path, from, to

  _nextTxnId: -> @id + '.' + ++@_opCount

  _queueTxn: Model::_queueTxn
  _addOpAsTxn: Model.genAddOpAsTxn
    callback: false
    getVer: -> @ver
    commit: false

  _specModel: Model::_specModel
  _applyMutation: Model::_applyMutation

  _conflictsWithMe: (txn) ->
    modelId = @id
    txns = @_txns
    txnQueue = @_txnQueue
    for id in txnQueue
      myTxn = txns[id]
      if @isMyOp id && transaction.doesSharePath(txn, myTxn) && ver < transaction.base txn
        return true
    return false
