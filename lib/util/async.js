module.exports = {
  finishAfter: finishAfter

, forEach: function (items, fn, done) {
    var finish = finishAfter(items.length, done);
    for (var i = 0, l = items.length; i < l; i++) {
      fn(items[i], finish);
    }
  }

, bufferifyMethods: function (Klass, methodNames, opts) {
    var await = opts.await
      , fns = {}
      , buffer = null;

    methodNames.forEach( function (methodName) {
      fns[methodName] = Klass.prototype[methodName];
      Klass.prototype[methodName] = function () {
        var didFlush = false
          , self = this;

        function flush () {
          didFlush = true;

          // When we call flush, we no longer need to buffer, so replace each
          // method with the original method
          methodNames.forEach( function (methodName) {
            self[methodName] = fns[methodName];
          });
          delete await.alreadyCalled;

          // Call the method with the first invocation arguments if this is
          // during the first call to methodName, await called flush
          // immediately, and we therefore have no buffered method calls.
          if (!buffer) return;

          // Otherwise, invoke the buffered method calls
          for (var i = 0, l = buffer.length; i < l; i++) {
            fns[methodName].apply(self, buffer[i]);
          }
          buffer = null;
        } /* end flush */

        // The first time we call methodName, run await
        if (await.alreadyCalled) return;
        await.alreadyCalled = true;
        await.call(this, flush);

        // If await decided we need no buffering and it called flush, then call
        // the original function with the arguments to this first call to methodName.
        if (didFlush) return this[methodName].apply(this, arguments);

        // Otherwise, if we need to buffer calls to this method, then replace
        // this method temporarily with code that buffers the method calls
        // until `flush` is called
        this[methodName] = function () {
          if (!buffer) buffer = [];
          buffer.push(arguments);
        }
        this[methodName].apply(this, arguments);
      }
    });
  }

, bufferify: function (methodName, opts) {
    var fn = opts.fn
      , await = opts.await
      , buffer = null;

    return function () {
      var didFlush = false
        , self = this;

      function flush () {
        didFlush = true;

        // When we call flush, we no longer need to buffer, so replace this
        // method with the original method
        self[methodName] = fn;

        // Call the method with the first invocation arguments if this is
        // during the first call to methodName, await called flush immediately,
        // and we therefore have no buffered method calls.
        if (!buffer) return;

        // Otherwise, invoke the buffered method calls
        for (var i = 0, l = buffer.length; i < l; i++) {
          fn.apply(self, buffer[i]);
        }
        buffer = null;
      }

      // The first time we call methodName, run awai
      await.call(this, flush);

      // If await decided we need no buffering and it called flush, then call
      // the original function with the arguments to this first call to methodName
      if (didFlush) return this[methodName].apply(this, arguments);

      // Otherwise, if we need to buffer calls to this method, then replace
      // this method temporarily with code that buffers the method calls until
      // `flush` is called
      this[methodName] = function () {
        if (!buffer) buffer = [];
        buffer.push(arguments);
      }
      this[methodName].apply(this, arguments);
    }
  }
};

function finishAfter (count, callback) {
  if (!callback) callback = function (err) { if (err) throw err; };
  if (!count || count === 1) return callback;
  var err;
  return function (_err) {
    err || (err = _err);
    --count || callback(err);
  };
}
