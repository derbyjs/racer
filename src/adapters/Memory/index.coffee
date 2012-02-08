##  WARNING:
##  ========
##  This file was compiled from a macro.
##  Do not edit it directly.

MemorySync = require '../MemorySync'
{deepCopy} = require '../../util'
MUTATORS = ['set', 'del', 'push', 'unshift', 'insert', 'pop', 'shift', 'remove', 'move']

Memory = module.exports = ->
  @_flush()
  return

Memory:: =
  Query: require './Query'

  _flush: MemorySync::flush
  flush: (callback) ->
    @_flush()
    callback null

  setVersion: MemorySync::setVersion

  _get: MemorySync::get
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
    adapter = this
    MUTATORS.forEach (method) ->
      store.defaultRoute method, '*', (args..., done, next) ->
        path = args[0]
        match = /^[^.]+\.[^.]+(?=\.|$)/.exec path
        docPath = if match then match[0] else path
        adapter.get docPath, (err, doc) ->
          return done err if err
          doc = deepCopy doc
          adapter[method] args..., (err) ->
            done err, doc

    store.defaultRoute 'get', '*', (path, done, next) ->
      adapter.get path, done
    store.defaultRoute 'get', '', (path, done, next) ->
      adapter.get '', done
    return

MUTATORS.forEach (method) ->
  alias = '_' + method
  Memory::[alias] = fn = MemorySync::[method]
  Memory::[method] = switch fn.length
    when 3 then (path, ver, callback) ->
      try
        @[alias] path, ver, null
      catch err
        return callback err
      callback null
    when 4 then (path, arg0, ver, callback) ->
      try
        @[alias] path, arg0, ver, null
      catch err
        return callback err
      callback null, arg0
    when 5 then (path, arg0, arg1, ver, callback) ->
      try
        @[alias] path, arg0, arg1, ver, null
      catch err
        return callback err
      callback null, arg0, arg1
    when 6 then (path, arg0, arg1, arg2, ver, callback) ->
      try
        @[alias] path, arg0, arg1, arg2, ver, null
      catch err
        return callback err
      callback null, arg0, arg1, arg2
    else (path, args..., ver, callback) ->
      try
        @[alias] path, args..., ver, null
      catch err
        return callback err
      callback null, args...

