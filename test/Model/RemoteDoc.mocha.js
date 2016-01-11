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
  docs(createDoc);
});
