##  WARNING:
##  ========
##  This file was compiled from a macro.
##  Do not edit it directly.

Memory = require '../../Memory'
{deepCopy} = require '../../util'
Query = require './Query'
MUTATORS = ['set', 'del', 'push', 'unshift', 'insert', 'pop', 'shift', 'remove', 'move']

module.exports = (racer) ->
  racer.adapters.db.Memory = DbMemory

DbMemory = ->
  @_flush()
  return

DbMemory:: =
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
  DbMemory::[alias] = fn = Memory::[method]
  DbMemory::[method] = switch fn.length
    when 3 then (path, ver, callback) ->
      try
        @[alias] path, ver, null
      catch err
        return callback err
      callback()
    when 4 then (path, arg0, ver, callback) ->
      try
        arg0 = deepCopy arg0
        @[alias] path, arg0, ver, null
      catch err
        return callback err
      callback()
    when 5 then (path, arg0, arg1, ver, callback) ->
      try
        arg0 = deepCopy arg0
        arg1 = deepCopy arg1
        @[alias] path, arg0, arg1, ver, null
      catch err
        return callback err
      callback()
    when 6 then (path, arg0, arg1, arg2, ver, callback) ->
      try
        arg0 = deepCopy arg0
        arg1 = deepCopy arg1
        arg2 = deepCopy arg2
        @[alias] path, arg0, arg1, arg2, ver, null
      catch err
        return callback err
      callback()
    else (path, args..., ver, callback) ->
      try
        args = deepCopy args
        @[alias] path, args..., ver, null
      catch err
        return callback err
      callback()
