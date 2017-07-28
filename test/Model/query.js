var expect = require('../util').expect;
var racer = require('../../lib');
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

  describe('idMap', function() {
    beforeEach('create in-memory backend and model', function() {
      this.backend = racer.createBackend();
      this.model = this.backend.createModel();
    });
    it('handles insert and remove of a duplicate id', function() {
      var query = this.model.query('myCollection', {key: 'myVal'});
      query.subscribe();
      query.shareQuery.emit('insert', [
        {id: 'a'},
        {id: 'b'},
        {id: 'c'}
      ], 0);
      // Add and immediately remove a duplicate id.
      query.shareQuery.emit('insert', [
        {id: 'a'}
      ], 3);
      query.shareQuery.emit('remove', [
        {id: 'a'}
      ], 3);
      // 'a' is still present once in the results, should still be in the map.
      expect(query.idMap).to.only.have.keys(['a', 'b', 'c']);
    });
  });
});
