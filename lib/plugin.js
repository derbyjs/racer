// Exports *plugin interface* implementation which is used for making
// extendable objects, for example see [`racer`](racer.html) module.
//
// This module allows to register any `object` as pluggable under a `name` via
// call to `_makePlugable`.
//
// Register *pluggable object* is called a `target` and it is told to be
// *decorated* by a plugin.
//
// Note: this module's exports are intended to be merged only into a *racer
// object*. When merged into a different objects, `use` method will be working
// incorrect in case when `plugin.decorate` will be set to "racer": it will
// decorate `this` object instead.
//
// TODO: fix `use` method to not use `this` but instead use `plugable['racer']`.

var util = require('./util')
  , mergeAll = util.mergeAll
  , isServer = util.isServer

    /* This tricks Browserify into not logging an error when bundling this file */
  , _require = require

  // This module also acts like a repository for all pluggable objects
  // registered via call to `_makePlugable`.
  , plugable = {};

module.exports = {

  // ## Making any object pluggable
  //
  // To register object as pluggable, just call `_makePlugable` specifying the
  // `name` under which it will be placed in the registry and reference that
  // `object` in a second parameter.
  //
  // This method only registers `object` as pluggable, to really make it
  // pluggable, merge `plugin` module into it, i.e. add *plugin interface*
  // implementation.
  //
  // Althought this method is exported and latter added to *racer object* it is
  // a static method, meaning that it does not has any impact on the object it
  // is called upon.
  _makePlugable: function (name, object) {
    plugable[name] = object;
  }


  // ## Adding plugins to racer object
  //
  // Later these pluggable objects can be instructed to use plugins by calls to
  // `use(plugin, options)`.
  //
  // A function representing `plugin` must have a `decorate` property to
  // specify which object to decorate, it can be `null` or a `String` used as a
  // `name` in call to `_makePlugable()` (e.g. `racer` or `derby`).
  /**
   * @param {Function} plugin(racer, options)
   * @param {Object} options that we pass to the plugin invocation
   */
, use: function (plugin, options) {
    // `plugin` is expected to be a function. It can also be a string, on client
    // such a call will be just omitted, while on server environment, this
    // string will be used as a module name to require. Module's `exports` must
    // be a function to be usef as a plugin.
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
    /* Ensure that plugin isn't already added, push it to the target's
       `_plugins` property and call it right away passing in `target` and
       `options`.
     */
    if (-1 === plugins.indexOf(plugin)) {
      plugins.push(plugin);
      plugin(target, options);
    }
    return this;
  }

  // ## Adding functionality to Model and Store objects
  //
  // Racer has a concept of *klass*: function with a prototype used as an object
  // constructor.
  //
  // Currently only two *klasses* are using mixin functionality: `Store` and
  // `Model`.
  //
  // Klasses can emit events on racer object to notify all attached mixins about
  // state changes. Set of this events are klass-specific, with only one common
  // event: `Klass:mixin` where `Klass` is a type of a klass. It is called every
  // time a new mixin is merged into a klass.
  //
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
  //
  // Note: most of plugins in racer set `useWith` property on a plugin function,
  // but as source code suggests, it is of no use as of racer-0.3.13.
, mixin: function () {
    var protected = this.protected;
    for (var i = 0, l = arguments.length; i < l; i++) {
      var mixin = arguments[i];

      // On client, mixin referenced by a string are just omitted, while on
      // server corresponding module will be required, and its `exports` object
      // will be used as a mixin.
      if (typeof mixin === 'string') {
        if (!isServer) continue;
        mixin = _require(mixin);
      }

      var type = mixin.type;
      if (!type) throw new Error('Mixins require a type parameter');
      var Klass = protected[type];
      if (!Klass) throw new Error('Cannot find racer.protected.' + type);

      // When adding mixin to the Klass for the first time, `mixinEmit` method
      // is set on it's prototype. This method is used to trigger a specially
      // named event on the racer object for which all Klass mixins can listen.
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

      // Mixin object can have a `server` property of `String` or `Object`. On
      // server, it will be used to extend Klass prototype.
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
