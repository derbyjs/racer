transaction = require '../transaction'

# TODO: These methods should be defined in one place based on the
# accessor and mutator properties of mixins

MAX_RETRIES = 20
RETRY_DELAY = 5  # Initial delay in milliseconds. Linearly increases

AsyncAtomic = (@async, @cb) ->
  @minVer = 0
  @count = 0
  return

AsyncAtomic:: =

  _reset: ->
    @minVer = 0
    @count = 0

  get: (path, callback) ->
    minVer = @minVer
    cb = @cb
    self = this
    @async.get path, (err, value, ver) ->
      return cb err if err
      self.minVer = if minVer then Math.min minVer, ver else ver
      callback value if callback

  set: (path, value, callback) ->
    @count++
    cb = @cb
    self = this
    @async.set path, value, @minVer, (err, value) ->
      return cb err if err
      callback null, value if callback
      cb() unless --self.count

  del: (path, callback) ->
    @count++
    cb = @cb
    self = this
    @async.del path, @minVer, (err) ->
      return cb err if err
      callback() if callback
      cb() unless --self.count

empty = ->

# TODO @model.store._commit is used in a non-private way. Change
#      to @model.store.commit
module.exports = Async = (@model) -> return
Async:: =

  # Note that async operation clientIds MUST begin with '#', as this is used to
  # treat conflict detection between async and sync transactions differently
  _nextTxnId: -> '#' + @model._nextTxnId()

  get: (path, callback) ->
    @model.store._adapter.get path, callback

  set: (path, value, ver, callback) ->
    txn = transaction.create base: ver, id: @_nextTxnId(), method: 'set', args: [path, value]
    @model.store._commit txn, callback

  del: (path, ver, callback) ->
    txn = transaction.create base: ver, id: @_nextTxnId(), method: 'del', args: [path]
    @model.store._commit txn, callback

  push: (path, items, ver, callback) ->
    txn = transaction.create base: ver, id: @_nextTxnId(), method: 'push', args: [path].concat(items)
    @model.store._commit txn, callback

  unshift: (path, items, ver, callback) ->
    txn = transaction.create base: ver, id: @_nextTxnId(), method: 'unshift', args: [path].concat(items)
    @model.store._commit txn, callback

  insert: (path, index, items, ver, callback) ->
    txn = transaction.create base: ver, id: @_nextTxnId(), method: 'insert', args: [path, index].concat(items)
    @model.store._commit txn, callback

  pop: (path, ver, callback) ->
    txn = transaction.create base: ver, id: @_nextTxnId(), method: 'pop', args: [path]
    @model.store._commit txn, callback

  shift: (path, ver, callback) ->
    txn = transaction.create base: ver, id: @_nextTxnId(), method: 'shift', args: [path]
    @model.store._commit txn, callback
  
  remove: (path, start, howMany, ver, callback) ->
    txn = transaction.create base: ver, id: @_nextTxnId(), method: 'remove', args: [path, start, howMany]
    @model.store._commit txn, callback

  move: (path, from, to, ver, callback) ->
    txn = transaction.create base: ver, id: @_nextTxnId(), method: 'move', args: [path, from, to]
    @model.store._commit txn, callback

  incr: (path, byNum, callback) ->
    if typeof byNum is 'function'
      # For incr(path, callback)
      callback = byNum
      byNum = 1
    else
      # For incr(path, [byNum])
      byNum ?= 1
      callback ||= empty
    
    tryVal = null
    @retry (atomic) ->
      atomic.get path, (val) ->
        atomic.set path, tryVal = (val || 0) + byNum
    , (err) -> callback err, tryVal

  setNull: (path, value, callback) ->
    tryVal = null
    @retry (atomic) ->
      atomic.get path, (val) ->
        return tryVal = val if val?
        atomic.set path, tryVal = value
    , (err) -> callback err, tryVal

  retry: (fn, callback) ->
    retries = MAX_RETRIES
    atomic = new AsyncAtomic this, (err) ->
      return callback && callback() unless err
      return callback && callback 'maxRetries' unless retries--
      atomic._reset()
      delay = (MAX_RETRIES - retries) * RETRY_DELAY
      setTimeout fn, delay, atomic
    fn atomic
