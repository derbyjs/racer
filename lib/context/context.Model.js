module.exports = {
  type: 'Model'
, events: {
    init: function (model) {
      model.scopedContext = null;
    }
  }
, proto: {
    context: function (name) {
      return Object.create(this, {
        scopedContext: { value: name }
      });
    }
  }
};
