var expect = require('../util').expect;
var racer = require('../../lib/index');
var RemoteDoc = require('../../lib/Model/RemoteDoc');
var docs = require('./docs');

describe('RemoteDoc', function() {
  function createDoc() {
    var backend = racer.createBackend();
    var model = backend.createModel();
    var doc = model.getOrCreateDoc('colors', 'green');
    doc.create();
    return doc;
  };
  describe('create', function() {
    it('should set the collectionName and id properties', function() {
      var doc = createDoc();
      expect(doc.collectionName).to.equal('colors');
      expect(doc.id).to.equal('green');
    });
  });
  describe('preventCompose', function() {
    beforeEach(function() {
      this.backend = racer.createBackend();
      this.model = this.backend.createModel();
    });
    it('composes ops by default', function(done) {
      var fido = this.model.at('dogs.fido');
      var doc = this.model.connection.get('dogs', 'fido');
      fido.create({age: 3});
      fido.increment('age', 2);
      fido.increment('age', 2, function(err) {
        if (err) return done(err);
        expect(doc.version).equal(1);
        expect(fido.get()).eql({id: 'fido', age: 7});
        fido.increment('age', 2);
        fido.increment('age', 2, function(err) {
          if (err) return done(err);
          expect(doc.version).equal(2);
          expect(fido.get()).eql({id: 'fido', age: 11});
          done();
        });
      });
    });
    it('does not compose ops on a model.preventCompose() child model', function(done) {
      var fido = this.model.at('dogs.fido').preventCompose();
      var doc = this.model.connection.get('dogs', 'fido');
      fido.create({age: 3});
      fido.increment('age', 2);
      fido.increment('age', 2, function(err) {
        if (err) return done(err);
        expect(doc.version).equal(3);
        expect(fido.get()).eql({id: 'fido', age: 7});
        fido.increment('age', 2);
        fido.increment('age', 2, function(err) {
          if (err) return done(err);
          expect(doc.version).equal(5);
          expect(fido.get()).eql({id: 'fido', age: 11});
          done();
        });
      });
    });
    it('composes ops on a model.allowCompose() child model', function(done) {
      var fido = this.model.at('dogs.fido').preventCompose();
      var doc = this.model.connection.get('dogs', 'fido');
      fido.create({age: 3});
      fido.increment('age', 2);
      fido.increment('age', 2, function(err) {
        if (err) return done(err);
        expect(doc.version).equal(3);
        expect(fido.get()).eql({id: 'fido', age: 7});
        fido = fido.allowCompose();
        fido.increment('age', 2);
        fido.increment('age', 2, function(err) {
          if (err) return done(err);
          expect(doc.version).equal(4);
          expect(fido.get()).eql({id: 'fido', age: 11});
          done();
        });
      });
    });
  });
  docs(createDoc);
});
