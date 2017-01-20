var expect = require('../util').expect;
var Model = require('../../lib/Model');

describe('Model', function() {
  describe('scope', function() {
    it('set scoped path with a callback', function() {
      var model = new Model
      var scoped = model.at('_page.shown');
      expect(scoped.get()).equal(void 0);
      scoped.set(false, function(err) {});
      expect(scoped.get()).eql(false);
    });
  });
});
