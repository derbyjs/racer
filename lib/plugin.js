var util = require('./util')
  , mergeAll = util.mergeAll
  , isServer = util.isServer

    // This tricks Browserify into not logging an error when bundling this file
  , _require = require

  , plugable = {};

module.exports = {

  _makePlugable: function (name, object) {
    plugable[name] = object;
  }

  /**
   * @param {Function} plugin(racer, options)
   * @param {Object} options that we pass to the plugin invocation
   */
, use: function (plugin, options) {
    if (typeof plugin === 'string') {
      if (!isServer) return this;
      plugin = _require(plugin);
    }

    var decorate = plugin.decorate
      , target = (decorate === null || decorate === 'racer')
               ? this
               : plugable[decorate];

    if (!target) {
      throw new Error('Invalid plugin.decorate value: ' + decorate);
    }

    var plugins = target._plugins || (target._plugins = []);

    // Don't include a plugin more than once -- useful in tests where race
    // conditions exist regarding require and clearing require.cache
    if (-1 === plugins.indexOf(plugin)) {
      plugins.push(plugin);
      plugin(target, options);
    }
    return this;
  }

  // A mixin is an object literal with:
  //   type:     Name of the racer Klass in which to mixin
  //   [static]: Class/static methods to add to Klass
  //   [proto]:  Methods to add to Klass.prototype
  //   [events]: Event callbacks including 'mixin', 'init', 'socket', etc.
  //
  // proto methods may be either a function or an object literal with:
  //   fn:       The method's function
  //   [type]:   Optionally add this method to a collection of methods accessible
  //             via Klass.<type>. If type is a comma-separated string,
  //             e.g., `type="foo,bar", then this method is added to several
  //             method collections, e.g., added to `Klass.foo` and `Klass.bar`.
  //             This is useful for grouping several methods together.
  //   <other>:  All other key-value pairings are added as properties of the method
, mixin: function () {
    var protected = this.protected;
    for (var i = 0, l = arguments.length; i < l; i++) {
      var mixin = arguments[i];
      if (typeof mixin === 'string') {
        if (!isServer) continue;
        mixin = _require(mixin);
      }

      var type = mixin.type;
      if (!type) throw new Error('Mixins require a type parameter');
      var Klass = protected[type];
      if (!Klass) throw new Error('Cannot find racer.protected.' + type);

      if (Klass.mixins) {
        Klass.mixins.push(mixin);
      } else {
        Klass.mixins = [mixin];
        var self = this;
        Klass.prototype.mixinEmit = function (name) {
          var eventName = type + ':' + name
            , eventArgs = Array.prototype.slice.call(arguments, 1);
          self.emit.apply(self, [eventName].concat(eventArgs));
        };
      }

      if (mixin.decorate) mixin.decorate(Klass);
      mergeAll(Klass, mixin.static);
      mergeProto(mixin.proto, Klass);

      var server;
      if (isServer && (server = mixin.server)) {
        server = (typeof server === 'string')
               ? _require(server)
               : mixin.server;
        mergeProto(server, Klass);
      }

      var events = mixin.events;
      for (var name in events) {
        var fn = events[name];
        this.on(type + ':' + name, fn);
      }

      this.emit(type + ':mixin', Klass);
    }
    return this;
  }
};

function mergeProto (protoSpec, Klass) {
  var targetProto = Klass.prototype;
  for (var name in protoSpec) {
    var descriptor = protoSpec[name];
    if (typeof descriptor === 'function') {
      targetProto[name] = descriptor;
      continue;
    }
    var fn = targetProto[name] = descriptor.fn;
    for (var key in descriptor) {
      var value = descriptor[key];
      switch (key) {
        case 'fn': continue;
        case 'type':
          var csGroups = value.split(',');
          for (var i = 0, l = csGroups.length; i < l; i++) {
            var groupName = csGroups[i]
              , methods = Klass[groupName] || (Klass[groupName] = {});
            methods[name] = fn;
          }
          break;
        default:
          fn[key] = value;
      }
    }
  }
}
