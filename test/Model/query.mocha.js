var expect = require('../util').expect;
var Model = require('../../lib/Model');

describe('query', function() {
  describe('sanitizeQuery', function() {
    it('replaces undefined with null in object query expressions', function() {
      var model = new Model();
      var query = model.query('foo', {x: undefined, y: 'foo'});
      expect(query.expression).eql({x: null, y: 'foo'});
    });
    it('replaces undefined with null in nested object query expressions', function() {
      var model = new Model();
      var query = model.query('foo', [{x: undefined}, {x: {y: undefined, z: 0}}]);
      expect(query.expression).eql([{x: null}, {x: {y: null, z: 0}}]);
    });
  });
});
