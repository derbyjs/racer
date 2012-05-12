{mergeAll, isServer} = require './util'

# This tricks Browserify into not logging an error when bundling this file
_require = require

module.exports =

  use: (plugin, options) ->
    if typeof plugin is 'string'
      return this unless isServer
      plugin = _require plugin

    this._plugins ||= []
    # Don't include a plugin more than once -- useful in tests where race
    # conditions exist regarding require and clearing require.cache
    if -1 == this._plugins.indexOf plugin
      this._plugins.push plugin
      plugin this, options
    return this

  # A mixin is an object literal with:
  #   type:     Name of the racer Klass in which to mixin
  #   [static]: Class/static methods to add to Klass
  #   [proto]:  Methods to add to Klass.prototype
  #   [events]: Event callbacks including 'mixin', 'init', 'socket', etc.
  #
  # proto methods may be either a function or an object literal with:
  #   fn:       The method's function
  #   [type]:   Optionally add this method to a collection of methods accessible
  #             via Klass.<type>. If type is a comma-separated string,
  #             e.g., `type="foo,bar", then this method is added to several
  #             method collections, e.g., added to `Klass.foo` and `Klass.bar`.
  #             This is useful for grouping several methods together.
  #   <other>:  All other key-value pairings are added as properties of the method
  mixin: ->
    for mixin in arguments
      if typeof mixin is 'string'
        continue unless isServer
        mixin = _require mixin

      unless type = mixin.type
        throw new Error "Mixins require a type parameter"
      unless Klass = @protected[type]
        throw new Error "Cannot find racer.protected.#{type}"

      if Klass.mixins
        Klass.mixins.push mixin
      else
        Klass.mixins = [mixin]
        Klass::mixinEmit = (name, args...) =>
          @emit type + ':' + name, args...

      mergeAll Klass, mixin.static

      mergeProto mixin.proto, Klass

      if isServer && (server = mixin.server)
        server =
          if typeof server is 'string'
          then _require server
          else mixin.server
        mergeProto server, Klass

      for name, fn of mixin.events
        @on type + ':' + name, fn

      @emit type + ':mixin', Klass

    return this

mergeProto = (protoSpec, Klass) ->
  targetPrototype = Klass::
  for name, descriptor of protoSpec
    if typeof descriptor is 'function'
      targetPrototype[name] = descriptor
      continue
    fn = targetPrototype[name] = descriptor.fn
    for key, value of descriptor
      switch key
        when 'fn' then continue
        when 'type' then for groupName in value.split ','
          methods = Klass[groupName] ||= {}
          methods[name] = fn
        else fn[key] = value
  return
