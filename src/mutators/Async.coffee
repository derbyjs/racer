transaction = require '../transaction'

# TODO: Implement remaining methods for AsyncAtomic
# TODO: Redo implementation using a macro

Async = module.exports = (options = {}) ->
  @get = options.get
  @_commit = options.commit

  # Note that async operation clientIds MUST begin with '#', as this is used to
  # treat conflict detection between async and sync transactions differently
  if nextTxnId = options.nextTxnId
    @_nextTxnId = (callback) -> callback null, '#' + nextTxnId()
  return

Async:: =

  set: (path, value, ver, callback) ->
    @_nextTxnId (err, id) =>
      txn = transaction.create ver: ver, id: id, method: 'set', args: [path, value]
      @_commit txn, callback

  del: (path, ver, callback) ->
    @_nextTxnId (err, id) =>
      txn = transaction.create ver: ver, id: id, method: 'del', args: [path]
      @_commit txn, callback

  push: (path, items, ver, callback) ->
    @_nextTxnId (err, id) =>
      txn = transaction.create ver: ver, id: id, method: 'push', args: [path].concat(items)
      @_commit txn, callback

  unshift: (path, items, ver, callback) ->
    @_nextTxnId (err, id) =>
      txn = transaction.create ver: ver, id: id, method: 'unshift', args: [path].concat(items)
      @_commit txn, callback

  insert: (path, index, items, ver, callback) ->
    @_nextTxnId (err, id) =>
      txn = transaction.create ver: ver, id: id, method: 'insert', args: [path, index].concat(items)
      @_commit txn, callback

  pop: (path, ver, callback) ->
    @_nextTxnId (err, id) =>
      txn = transaction.create ver: ver, id: id, method: 'pop', args: [path]
      @_commit txn, callback

  shift: (path, ver, callback) ->
    @_nextTxnId (err, id) =>
      txn = transaction.create ver: ver, id: id, method: 'shift', args: [path]
      @_commit txn, callback

  remove: (path, start, howMany, ver, callback) ->
    @_nextTxnId (err, id) =>
      txn = transaction.create ver: ver, id: id, method: 'remove', args: [path, start, howMany]
      @_commit txn, callback

  move: (path, from, to, howMany, ver, callback) ->
    @_nextTxnId (err, id) =>
      txn = transaction.create ver: ver, id: id, method: 'move', args: [path, from, to, howMany]
      @_commit txn, callback

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
      return callback?() unless err
      return callback? 'maxRetries' unless retries--
      atomic._reset()
      setTimeout fn, RETRY_DELAY, atomic
    fn atomic

Async.MAX_RETRIES = MAX_RETRIES = 20
Async.RETRY_DELAY = RETRY_DELAY = 100
empty = ->

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
    @async.get path, (err, value, ver) =>
      return cb err if err
      @minVer = if minVer then Math.min minVer, ver else ver
      callback? value

  set: (path, value, callback) ->
    @count++
    cb = @cb
    @async.set path, value, @minVer, (err, value) =>
      return cb err if err
      callback? null, value
      cb() unless --@count

  del: (path, callback) ->
    @count++
    cb = @cb
    @async.del path, @minVer, (err) =>
      return cb err if err
      callback?()
      cb() unless --@count
