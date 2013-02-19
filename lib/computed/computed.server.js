module.exports = {
  _onCreateFilter: function (transformBuilder) {
    var args = ['_loadFilter', transformBuilder];
    this._filtersToBundle.push(args);
  }
};
