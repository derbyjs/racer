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

  describe('Query', function() {
    beforeEach('create in-memory backend and model', function() {
      this.backend = racer.createBackend();
      this.model = this.backend.createModel();
    });
    it('Uses deep copy of query expression in Query constructor', function() {
      var expression = {arrayKey: []};
      var query = this.model.query('myCollection', expression);
      query.fetch();
      expression.arrayKey.push('foo');
      expect(query.expression.arrayKey).to.have.length(0);
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
      expect(query.idMap).to.have.all.keys(['a', 'b', 'c']);
    });
  });

  describe('instantiation', function() {
    it('returns same instance when params are equivalent', function() {
      var model = new Model();
      var query1 = model.query('foo', {value: 1}, {db: 'other'});
      var query2 = model.query('foo', {value: 1}, {db: 'other'});
      expect(query1).equal(query2);
    });
    it('returns same instance when context and params are equivalent', function() {
      var model = new Model();
      var query1 = model.context('box').query('foo', {});
      var query2 = model.context('box').query('foo', {});
      expect(query1).equal(query2);
    });
    it('creates a unique query instance per collection name', function() {
      var model = new Model();
      var query1 = model.query('foo', {});
      var query2 = model.query('bar', {});
      expect(query1).not.equal(query2);
    });
    it('creates a unique query instance per expression', function() {
      var model = new Model();
      var query1 = model.query('foo', {value: 1});
      var query2 = model.query('foo', {value: 2});
      expect(query1).not.equal(query2);
    });
    it('creates a unique query instance per options', function() {
      var model = new Model();
      var query1 = model.query('foo', {}, {db: 'default'});
      var query2 = model.query('foo', {}, {db: 'other'});
      expect(query1).not.equal(query2);
    });
    it('creates a unique query instance per context', function() {
      var model = new Model();
      var query1 = model.query('foo', {});
      var query2 = model.context('box').query('foo', {});
      expect(query1).not.equal(query2);
    });
  });

  describe('reference counting', function() {
    it('fetch uses the root model context', function(done) {
      var backend = racer.createBackend();
      var model = backend.createModel();
      var query = model.query('foo', {});
      query.fetch(function(err) {
        if (err) return done(err);
        expect(model._contexts.root.fetchedQueries[query.hash]).equal(1);
        done();
      });
    });
    it('fetch of same query in different context uses the specified model context', function(done) {
      var backend = racer.createBackend();
      var model = backend.createModel();
      model.query('foo', {});
      // Same query params in different context:
      var query = model.context('box').query('foo', {});
      query.fetch(function(err) {
        if (err) return done(err);
        expect(model._contexts.box.fetchedQueries[query.hash]).equal(1);
        done();
      });
    });
  });
});
