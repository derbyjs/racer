var RemoteDoc, docs, expect;

expect = require('../util').expect;

RemoteDoc = require('../../lib/Model/RemoteDoc');

docs = require('./docs');

describe('RemoteDoc', function() {
  var createDoc;
  createDoc = function() {
    return new RemoteDoc('colors', 'green');
  };
  return describe('create', function() {
    return it.skip('should set the collectionName and id properties', function() {
      var doc;
      doc = createDoc();
      expect(doc.collectionName).to.equal('colors');
      return expect(doc.id).to.equal('green');
    });
  });
});
