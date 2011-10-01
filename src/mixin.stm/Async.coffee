transaction = require '../transaction'

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

  incr: (path, byNum, callback) ->
    if typeof byNum is 'function'
      # For incr(path, callback)
      callback = byNum
      byNum = 1
    else
      # For incr(path)
      byNum ?= 1
    
    tryVal = null
    @retry (atomic) ->
      atomic.get path, (val) ->
        atomic.set path, tryVal = (val || 0) + byNum
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
