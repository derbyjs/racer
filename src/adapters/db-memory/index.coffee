Memory = require '../../Memory'
{mergeAll, deepCopy} = require '../../util'
Query = require '../../descriptor/query/MemoryQuery'

MUTATORS = ['set', 'del', 'push', 'unshift', 'insert', 'pop', 'shift', 'remove', 'move']
routePattern = /^[^.]+(?:\.[^.]+)?(?=\.|$)/

exports = module.exports = (racer) ->
  racer.registerAdapter 'db', 'Memory', DbMemory

exports.useWith = server: true, browser: false
exports.decorate = 'racer'

exports.adapter = DbMemory = ->
  @_flush()
  return

mergeAll DbMemory::, Memory::,
  Query: Query

  _flush: Memory::flush
  flush: (callback) ->
    @_flush()
    callback null

  setVersion: Memory::setVersion

  _get: Memory::get
  get: (path, callback) ->
    try
      val = @_get path
    catch err
      return callback err
    callback null, deepCopy(val), @version

  setupRoutes: (store) ->
    MUTATORS.forEach (method) =>
      store.route method, '*', -1000, (path, args..., ver, done, next) =>
        args = deepCopy args
        match = routePattern.exec path
        docPath = match && match[0]
        topDocPath = docPath.split('.')[0..1].join('.')
        @get topDocPath, (err, topDoc) =>
          topDoc = deepCopy topDoc
          @get docPath, (err, doc) =>
            return done err if err
            oldDoc = topDoc
            try
              @[method] path, args..., ver, null
            catch err
              return done err, oldDoc
            done null, oldDoc

    getFn = (path, done, next) => @get path, done
    store.route 'get', '*', -1000, getFn
