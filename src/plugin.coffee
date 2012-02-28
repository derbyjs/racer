{mergeAll, isServer} = require './util'

module.exports =

  use: (plugin, options) ->
    if typeof plugin is 'string'
      return unless isServer
      plugin = require plugin

    plugin this, options
    return this

  # A mixin is an object literal with:
  #   type:     Name of the racer Klass in which to mixin
  #   [static]: Class/static methods to add to Klass
  #   [proto]:  Methods to add to Klass.prototype
  #   [events]: Event callbacks including 'mixin', 'init', 'socket', ect.
  #
  # proto methods may be either a function or an object literal with:
  #   fn:       The method's function
  #   [type]:   Optional string containing a comma-separated list of groups.
  #             A reference to the method is added in an object on the Klass
  #             with the group name
  #   <other>:  All other key-value pairings are added as properties of the method
  mixin: ->
    for mixin in arguments
      if typeof mixin is 'string'
        continue unless isServer
        mixin = require mixin

      {type} = mixin
      Klass = @[type]
      unless Klass
        throw new Error "Cannot find racer.#{type}"

      if Klass.mixins
        Klass.mixins.push mixin
      else
        Klass.mixins = [mixin]
        Klass::mixinEmit = emitFn this, type

      mergeAll Klass, mixin.static

      proto = Klass::
      mergeProto = (items) ->
        for name, item of items
          if fn = item.fn
            for key, value of item
              continue if key is 'fn'
              if key is 'type'
                for groupName in value.split ','
                  group = Klass[groupName] || Klass[groupName] = {}
                  group[name] = fn
                continue
              fn[key] = value
            proto[name] = fn
            continue
          proto[name] = item
        return

      mergeProto mixin.proto

      if isServer && (server = mixin.server)
        if typeof server is 'string'
          mergeProto require server
        else
          mergeProto mixin.server

      @emit type + ':mixin', Klass

      for name, fn of mixin.events
        @on type + ':' + name, fn

    return this

emitFn = (self, type) ->
  (name, args...) -> self.emit type + ':' + name, args...
