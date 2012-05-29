var pathUtils             = require('../path')
  , isPrivate             = pathUtils.isPrivate
  , regExpPathOrParent    = pathUtils.regExpPathOrParent
  , regExpPathsOrChildren = pathUtils.regExpPathsOrChildren
  , derefPath             = require('./util').derefPath
  , createRef             = require('./ref')
  , createRefList         = require('./refList')
  , util                  = require('../util')
  , isServer              = util.isServer
  , equal                 = util.equal
  , racer                 = require('../racer')
  ;

exports = module.exports = plugin;
exports.useWith = { server: true, browser: true };
exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(mixin);
}

var mixin = {
  type: 'Model'

, server: __dirname + '/refs.server'
, events: {
    init: function (model) {
      // [[from, get, item], ...]
      model._refsToBundle = [];

      // [['fn', path, inputs..., cb.toString()], ...]
      model._fnsToBundle = [];

      var Model = model.constructor;

      for (var method in Model.mutator) {
        model.on(method, (function (method) {
          return function (args) {
            var path = args[0];
            model.emit('mutator', method, path, arguments);
          };
        })(method));
      }

      var memory = model._memory;
      model.on('beforeTxn', function (method, args) {
        var path = args[0];
        if (!path) return;

        // De-reference transactions to operate on their absolute path
        var data = model._specModel()
          , obj  = memory.get(path, data)
          , fn   = data.$deref;
        if (fn) {
          args[0] = fn(method, args, model, obj);
        }
      });
    }

  , bundle: function (model) {
      var onLoad       = model._onLoad
        , refsToBundle = model._refsToBundle
        , fnsToBundle  = model._fnsToBundle;

      for (var i = 0, l = refsToBundle.length; i < l; i++) {
        var triplet = refsToBundle[i]
          , from    = triplet[0]
          , get     = triplet[1]
          , item    = triplet[2];
        if (model._getRef(from) === get) {
          onLoad.push(item);
        }
      }

      for (i = 0, l = fnsToBundle; i < l; i++) {
        var item = fnsToBundle[i];
        if (item) onLoad.push(item);
      }
    }
  }

, proto: {
    _getRef: function (path) {
      return this._memory.get(path, this._specModel(), true);
    }
  , _ensurePrivateRefPath: function (from, modelMethod) {
      if (! isPrivate(this.dereference(from, true)) ) {
        throw new Error('Cannot create ' + modelMethod + ' on public path ' + from);
      }
    }
  , dereference: function (path, getRef) {
      if (!getRef) getRef = false;
      var data = this._specModel();
      this._memory.get(path, data, getRef);
      return derefPath(data, path);
    }
  , ref: function (from, to, key, hardLink) {
      return this._createRef(createRef, 'ref', from, to, key, hardLink);
    }
  , refList: function (from, to, key, hardLink) {
      return this._createRef(createRefList, 'refList', from, to, key, hardLink);
    }
  , _createRef: function (refFactory, modelMethod, from, to, key, hardLink) {
      // Normalize `from`, `to`, `key` if we are a model scope
      if (this._at) {
        hardLink = key;
        key = to;
        to = from;
        from = this._at;
      } else if (from._at) {
        from = from._at;
      }
      if (to._at)         to  = to._at;
      if (key && key._at) key = key._at;

      var model = this._root;

      model._ensurePrivateRefPath(from, modelMethod);
      var get = refFactory(model, from, to, key, hardLink);

      // Prevent emission of the next set event, since we are setting the
      // dereferencing function and not its value.
      var listener = model.on('beforeTxn', function (method, args) {
        // Supress emission of set events when setting a function, which is
        // what happens when a ref is created
        if (method === 'set' && args[1] === get) {
          args.cancelEmit = true;
          model.removeListener('beforeTxn', listener);
        }
      });

      var previous = model.set(from, get);
      // Emit a set event with the expected de-referenced values
      var value = model.get(from);
      model.emit('set', [from, value], previous, true, undefined);

      // The server model adds [from, get, [modelMethod, from, to, key]] to
      // this._refsToBundle
      if (this._onCreateRef) {
        this._onCreateRef(modelMethod, from, to, key, get);
      }

      return model.at(from);
    }

    // model.fn(inputs... ,fn);
    //
    // Defines a reactive value that depends on the paths represented by
    // `inputs`, which are used by `fn` to re-calculate a return value every
    // time any of the `inputs` change.
  , fn: function () {
      var arglen = arguments.length
        , inputs = Array.prototype.slice.call(arguments, 0, arglen-1)
        , fn = arguments[arglen-1];

      // Convert scoped models into paths
      for (var i = 0, l = inputs.length; i < l; i++) {
        var input = inputs[i]
          , fullPath = input._at;
        if (fullPath) inputs[i] = fullPath;
      }

      var path = (this._at) // If we are a scoped model, scoped to this._at
               ? this._at + '.' + inputs.shift()
               : inputs.shift();
      var model = this._root;

      model._ensurePrivateRefPath(path, 'fn');
      if (typeof fn === 'string') {
        fn = (new Function('return + fn'))();
      }
      return model._createFn(path, inputs, fn);
    }

    /**
     * @param {String} path to the reactive value
     * @param {[String]} inputs is a list of paths from which the reactive
     * value is calculated
     * @param {Function} fn returns the reactive value at `path` calculated
     * from the values at the paths defined by `inputs`
     */
  , _createFn: function (path, inputs, fn, destroy) {
      var prevVal, currVal
        , reSelf = regExpPathOrParent(path)
        , reInput = regExpPathsOrChildren(inputs)
        , destroy = this._onCreateFn && this._onCreateFn(path, inputs, fn)
        , self = this;

      var listener = this.on('mutator', function (mutator, mutatorPath, _arguments) {
        // Ignore mutations created by this reactive function
        if (_arguments[3] === listener) return;

        // Remove reactive function if something else sets the value of its
        // output path. We get the current value here, since a mutator might
        // operate on the path or the parent path that does not actually affect
        // the reactive function. The equal function is true if the objects are
        // identical or if they are both NaN
        if (reSelf.test(mutatorPath) && ! equal(self.get(path), currVal)) {
          self.removeListener('mutator', listener);
          return destroy && destroy();
        }

        if (reInput.test(mutatorPath)) {
          currVal = updateVal();
        }
      });

      var model = this.pass(listener);

      var updateVal = function () {
        prevVal = currVal;
        var inputVals = [];
        for (var i = 0, l = inputs.length; i < l; i++) {
          inputVals.push(self.get(inputs[i]));
        }
        currVal = fn.apply(null, inputVals);
        if (equal(prevVal, currVal)) return currVal;
        model.set(path, currVal);
        return currVal;
      };
      return updateVal();
    }
  }
};
