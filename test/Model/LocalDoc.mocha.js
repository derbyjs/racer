var LocalDoc, docs, expect;

expect = require('../util').expect;

LocalDoc = require('../../lib/Model/LocalDoc');

docs = require('./docs');

describe('LocalDoc', function() {
  var createDoc;
  createDoc = function() {
    return new LocalDoc('_colors', 'green');
  };
  describe('create', function() {
    return it('should set the collectionName and id properties', function() {
      var doc;
      doc = createDoc();
      expect(doc.collectionName).to.equal('_colors');
      return expect(doc.id).to.equal('green');
    });
  });
  return docs(createDoc);
});
