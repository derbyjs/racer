Memory = require '../../Memory'
{mergeAll, deepCopy} = require '../../util'
Query = require './Query'

MUTATORS = ['set', 'del', 'push', 'unshift', 'insert', 'pop', 'shift', 'remove', 'move']
routePattern = /^[^.]+(?:\.[^.]+)?(?=\.|$)/

exports = module.exports = (racer) ->
  racer.adapters.db.Memory = DbMemory

exports.useWith = server: true, browser: false

DbMemory = ->
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
    callback null, val, @version

  filter: (predicate, namespace) ->
    data = @_get()
    if namespace
      docs = data[namespace]
      return (doc for id, doc of docs when predicate doc, "#{namespace}.#{id}")

    results = []
    for namespace, docs of data
      newResults = (doc for id, doc of docs when predicate doc, "#{namespace}.#{id}")
      results.push newResults...
    return results

  setupDefaultPersistenceRoutes: (store) ->
    MUTATORS.forEach (method) =>
      store.defaultRoute method, '*', (path, args..., ver, done, next) =>
        args = deepCopy args
        match = routePattern.exec path
        docPath = match && match[0]
        @get docPath, (err, doc) =>
          return done err if err
          doc = deepCopy doc
          try
            @[method] path, args..., ver, null
          catch err
            return done err, doc
          done null, doc

    getFn = (path, done, next) => @get path, done
    store.defaultRoute 'get', '*', getFn
    store.defaultRoute 'get', '', getFn
