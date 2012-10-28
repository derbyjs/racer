module.exports = {
  type: 'Model'

, events: {
    socket: function (model, socket) {
      var memory = model._memory;
      // When the store asks the browser model to re-sync with the store, then
      // the model should send the store its subscriptions and handle the
      // receipt of instructions to get the model state back in sync with the
      // store state (e.g., in the form of applying missed transaction, or in
      // the form of diffing to a received store state)
      socket.on('resyncWithStore', function (fn) {
        var subs = model._subs();
        fn(subs, memory.version, model._startId);
      });
    }
  }
};
