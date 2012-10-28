module.exports = {
  type: 'Store'
, events: {
    init: function (store) {
      // This stores the contexts by name. Contexts are objects that we
      // decorate with things like _validators.
      store._contexts = {};

      store._eachContexts = [];

      store.context('default');
      store.currContext = store.context('default');
    }
  }
, proto: {
    /**
     * Defines or re-opens an existing context.
     * If a callback is provided, anything inside the callback block is
     * executed with respect to the context. Any prior eachContext calls are
     * invoked on the new context.
     *
     * executed with respect to the context. Any prior eachContext calls are
     * invoked on the new context.
     *
     * @param {String} name of the context
     * @param {Function} callback
     * @return {Object} the context object
     */
    context: function (name, callback) {
      name || (name = 'default');
      var preContext = this.currContext
        , contexts = this._contexts

          // Find or create the context
        , context = this.currContext = contexts[name];

      if (!context) {
        context = this.currContext = contexts[name] = {
          name: name
        };
        var eachContexts = this._eachContexts, i;
        // Apply prior eachContext callbacks to the new context
        for (i = eachContexts.length; i--; ) {
          eachContexts[i](context);
        }
      }

      callback && callback();

      // reset currContext
      this.currContext = preContext;

      return context;
    }

    /**
     * Passes every context we have defined
     * @param {Function} callback
     * @return {Store} store for chaining
     */
  , eachContext: function (callback) {
      var contexts = this._contexts
        , eachContexts = this._eachContexts;
      for (var name in contexts) {
        callback(contexts[name]);
      }
      eachContexts.push(callback);
      return this;
    }
  }
};
