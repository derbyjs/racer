var expect = require('../util').expect;
var Model = require('./MockConnectionModel');
var RemoteDoc = require('../../lib/Model/RemoteDoc');
var docs = require('./docs');

describe('RemoteDoc', function() {
  function createDoc() {
    var model = new Model;
    model.createConnection();
    model.data.colors = {};
    return new RemoteDoc(model, 'colors', 'green');
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
