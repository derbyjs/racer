var expect;

expect = require('../util').expect;

module.exports = function(createDoc) {
  describe('get', function() {
    it('creates an undefined doc', function() {
      var doc;
      doc = createDoc();
      return expect(doc.get()).eql(void 0);
    });
    it('gets a defined doc', function() {
      var doc;
      doc = createDoc();
      doc.set([], {
        id: 'green'
      }, function() {});
      return expect(doc.get()).eql({
        id: 'green'
      });
    });
    it('gets a property on an undefined document', function() {
      var doc;
      doc = createDoc();
      return expect(doc.get(['id'])).eql(void 0);
    });
    it('gets an undefined property', function() {
      var doc;
      doc = createDoc();
      doc.set([], {}, function() {});
      return expect(doc.get(['id'])).eql(void 0);
    });
    it('gets a defined property', function() {
      var doc;
      doc = createDoc();
      doc.set([], {
        id: 'green'
      }, function() {});
      return expect(doc.get(['id'])).eql('green');
    });
    it('gets a false property', function() {
      var doc;
      doc = createDoc();
      doc.set([], {
        id: 'green',
        shown: false
      }, function() {});
      return expect(doc.get(['shown'])).eql(false);
    });
    it('gets a null property', function() {
      var doc;
      doc = createDoc();
      doc.set([], {
        id: 'green',
        shown: null
      }, function() {});
      return expect(doc.get(['shown'])).eql(null);
    });
    it('gets a method property', function() {
      var doc;
      doc = createDoc();
      doc.set([], {
        empty: ''
      }, function() {});
      return expect(doc.get(['empty', 'charAt'])).eql(''.charAt);
    });
    it('gets an array member', function() {
      var doc;
      doc = createDoc();
      doc.set([], {
        rgb: [0, 255, 0]
      }, function() {});
      return expect(doc.get(['rgb', '1'])).eql(255);
    });
    return it('gets an array length', function() {
      var doc;
      doc = createDoc();
      doc.set([], {
        rgb: [0, 255, 0]
      }, function() {});
      return expect(doc.get(['rgb', 'length'])).eql(3);
    });
  });
  describe('set', function() {
    it('sets an empty doc', function() {
      var doc, previous;
      doc = createDoc();
      previous = doc.set([], {}, function() {});
      expect(previous).equal(void 0);
      return expect(doc.get()).eql({});
    });
    it('sets a property', function() {
      var doc, previous;
      doc = createDoc();
      previous = doc.set(['shown'], false, function() {});
      expect(previous).equal(void 0);
      return expect(doc.get()).eql({
        shown: false
      });
    });
    it('sets a multi-nested property', function() {
      var doc, previous;
      doc = createDoc();
      previous = doc.set(['rgb', 'green', 'float'], 1, function() {});
      expect(previous).equal(void 0);
      return expect(doc.get()).eql({
        rgb: {
          green: {
            float: 1
          }
        }
      });
    });
    it('sets on an existing document', function() {
      var doc, previous;
      doc = createDoc();
      previous = doc.set([], {}, function() {});
      expect(previous).equal(void 0);
      expect(doc.get()).eql({});
      previous = doc.set(['shown'], false, function() {});
      expect(previous).equal(void 0);
      return expect(doc.get()).eql({
        shown: false
      });
    });
    it('returns the previous value on set', function() {
      var doc, previous;
      doc = createDoc();
      previous = doc.set(['shown'], false, function() {});
      expect(previous).equal(void 0);
      expect(doc.get()).eql({
        shown: false
      });
      previous = doc.set(['shown'], true, function() {});
      expect(previous).equal(false);
      return expect(doc.get()).eql({
        shown: true
      });
    });
    it('creates an implied array on set', function() {
      var doc;
      doc = createDoc();
      doc.set(['rgb', '2'], 0, function() {});
      doc.set(['rgb', '1'], 255, function() {});
      doc.set(['rgb', '0'], 127, function() {});
      return expect(doc.get()).eql({
        rgb: [127, 255, 0]
      });
    });
    return it.skip('creates an implied object on an array', function(done) {
      var doc;
      doc = createDoc();
      doc.set('colors', []);
      doc.set('colors.0.value', 'green');
      return expect(doc.get()).eql([
        {
          'value': 'green'
        }
      ]);
    });
  });
  describe('del', function() {
    it('can del on an undefined path without effect', function() {
      var doc, previous;
      doc = createDoc();
      previous = doc.del(['rgb', '2'], function() {});
      expect(previous).equal(void 0);
      return expect(doc.get()).eql(void 0);
    });
    it('can del on a document', function() {
      var doc, previous;
      doc = createDoc();
      doc.set([], {}, function() {});
      previous = doc.del([], function() {});
      expect(previous).eql({});
      return expect(doc.get()).eql(void 0);
    });
    return it('can del on a nested property', function() {
      var doc, previous;
      doc = createDoc();
      doc.set(['rgb'], [
        {
          float: 0,
          int: 0
        }, {
          float: 1,
          int: 255
        }, {
          float: 0,
          int: 0
        }
      ], function() {});
      previous = doc.del(['rgb', '0', 'float'], function() {});
      expect(previous).eql(0);
      return expect(doc.get(['rgb'])).eql([
        {
          int: 0
        }, {
          float: 1,
          int: 255
        }, {
          float: 0,
          int: 0
        }
      ]);
    });
  });
  return describe('push', function() {
    it('can push on an undefined property', function() {
      var doc, len;
      doc = createDoc();
      len = doc.push(['friends'], 'jim', function() {});
      expect(len).equal(1);
      return expect(doc.get()).eql({
        friends: ['jim']
      });
    });
    it('can push on a defined array', function() {
      var doc, len;
      doc = createDoc();
      len = doc.push(['friends'], 'jim', function() {});
      expect(len).equal(1);
      len = doc.push(['friends'], 'sue', function() {});
      expect(len).equal(2);
      return expect(doc.get()).eql({
        friends: ['jim', 'sue']
      });
    });
    return it('throws a TypeError when pushing on a non-array', function(done) {
      var doc;
      doc = createDoc();
      doc.set(['friends'], {}, function() {});
      return doc.push(['friends'], ['x'], function(err) {
        expect(err).a(TypeError);
        return done();
      });
    });
  });
};
