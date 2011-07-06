module.exports = MongoAdapter = (config) ->
  @client = new Db config.db, new Server(config.host, config.port, {})
  return

MongoAdapter:: =
  flush: (callback) ->
    # TODO
  set: (path, val, ver, callback) ->
    # TODO
  get: (path,callback) ->
    # TODO
  mget: (paths, callback) ->
    # TODO
  extract: (path) ->
    # TODO DRY - duplicated in Memory adapter
    parts = path.split '.'
    first = parts.slice(0,2).join('.')
    rest  = parts.slice(2).join('.')
    [first, rest]
