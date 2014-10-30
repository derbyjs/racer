var expect = require('../util').expect;

module.exports = function(createDoc) {
  describe('get', function() {
    it('creates an undefined doc', function() {
      var doc = createDoc();
      expect(doc.get()).eql(void 0);
    });
    it('gets a defined doc', function() {
      var doc = createDoc();
      doc.set([], {
        id: 'green'
      }, function() {});
      expect(doc.get()).eql({
        id: 'green'
      });
    });
    it('gets a property on an undefined document', function() {
      var doc = createDoc();
      expect(doc.get(['x'])).eql(void 0);
    });
    it('gets an undefined property', function() {
      var doc = createDoc();
      doc.set([], {}, function() {});
      expect(doc.get(['x'])).eql(void 0);
    });
    it('gets a defined property', function() {
      var doc = createDoc();
      doc.set([], {
        'id': 'green'
      }, function() {});
      expect(doc.get(['id'])).eql('green');
    });
    it('gets a false property', function() {
      var doc = createDoc();
      doc.set([], {
        shown: false
      }, function() {});
      expect(doc.get(['shown'])).eql(false);
    });
    it('gets a null property', function() {
      var doc = createDoc();
      doc.set([], {
        shown: null
      }, function() {});
      expect(doc.get(['shown'])).eql(null);
    });
    it('gets a method property', function() {
      var doc = createDoc();
      doc.set([], {
        empty: ''
      }, function() {});
      expect(doc.get(['empty', 'charAt'])).eql(''.charAt);
    });
    it('gets an array member', function() {
      var doc = createDoc();
      doc.set([], {
        rgb: [0, 255, 0]
      }, function() {});
      expect(doc.get(['rgb', '1'])).eql(255);
    });
    it('gets an array length', function() {
      var doc = createDoc();
      doc.set([], {
        rgb: [0, 255, 0]
      }, function() {});
      expect(doc.get(['rgb', 'length'])).eql(3);
    });
  });
  describe('set', function() {
    it('sets a property', function() {
      var doc = createDoc();
      var previous = doc.set(['shown'], false, function() {});
      expect(previous).equal(void 0);
      expect(doc.get(['shown'])).eql(false);
    });
    it('sets a multi-nested property', function() {
      var doc = createDoc();
      var previous = doc.set(['rgb', 'green', 'float'], 1, function() {});
      expect(previous).equal(void 0);
      expect(doc.get(['rgb'])).eql({
        green: {
          float: 1
        }
      });
    });
    it('sets on an existing document', function() {
      var doc = createDoc();
      var previous = doc.set([], {
        id: 'green'
      }, function() {});
      expect(previous).equal(void 0);
      expect(doc.get()).eql({
        id: 'green'
      });
      previous = doc.set(['shown'], false, function() {});
      expect(previous).equal(void 0);
      expect(doc.get()).eql({
        id: 'green',
        shown: false
      });
    });
    it('returns the previous value on set', function() {
      var doc = createDoc();
      var previous = doc.set(['shown'], false, function() {});
      expect(previous).equal(void 0);
      expect(doc.get(['shown'])).eql(false);
      previous = doc.set(['shown'], true, function() {});
      expect(previous).equal(false);
      expect(doc.get(['shown'])).eql(true);
    });
    it('creates an implied array on set', function() {
      var doc = createDoc();
      doc.set(['rgb', '2'], 0, function() {});
      doc.set(['rgb', '1'], 255, function() {});
      doc.set(['rgb', '0'], 127, function() {});
      expect(doc.get(['rgb'])).eql([127, 255, 0]);
    });
    it('creates an implied object on an array', function() {
      var doc = createDoc();
      doc.set(['colors'], [], function() {});
      doc.set(['colors', '0', 'value'], 'green', function() {});
      expect(doc.get(['colors'])).eql([
        {
          value: 'green'
        }
      ]);
    });
  });
  describe('del', function() {
    it('can del on an undefined path without effect', function() {
      var doc = createDoc();
      var previous = doc.del(['rgb', '2'], function() {});
      expect(previous).equal(void 0);
      expect(doc.get()).eql(void 0);
    });
    it('can del on a document', function() {
      var doc = createDoc();
      doc.set([], {
        id: 'green'
      }, function() {});
      var previous = doc.del([], function() {});
      expect(previous).eql({
        id: 'green'
      });
      expect(doc.get()).eql(void 0);
    });
    it('can del on a nested property', function() {
      var doc = createDoc();
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
      var previous = doc.del(['rgb', '0', 'float'], function() {});
      expect(previous).eql(0);
      expect(doc.get(['rgb'])).eql([
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
  describe('push', function() {
    it('can push on an undefined property', function() {
      var doc = createDoc();
      var len = doc.push(['friends'], 'jim', function() {});
      expect(len).equal(1);
      expect(doc.get(['friends'])).eql(['jim']);
    });
    it('can push on a defined array', function() {
      var doc = createDoc();
      var len = doc.push(['friends'], 'jim', function() {});
      expect(len).equal(1);
      len = doc.push(['friends'], 'sue', function() {});
      expect(len).equal(2);
      expect(doc.get(['friends'])).eql(['jim', 'sue']);
    });
    it('throws a TypeError when pushing on a non-array', function(done) {
      var doc = createDoc();
      doc.set(['friends'], {}, function() {});
      doc.push(['friends'], ['x'], function(err) {
        expect(err).a(TypeError);
        done();
      });
    });
  });
  describe('move', function() {
    it('can move an item from the end to the beginning of the array', function() {
      var doc = createDoc();
      doc.set(['array'], [0, 1, 2, 3, 4], function() {});
      var moved = doc.move(['array'], 4, 0, 1, function() {});
      expect(moved).eql([4]);
      expect(doc.get(['array'])).eql([4, 0, 1, 2, 3]);
    });
    it('can swap the first two items in the array', function() {
      var doc = createDoc();
      doc.set(['array'], [0, 1, 2, 3, 4], function() {});
      var moved = doc.move(['array'], 1, 0, 1, function() {});
      expect(moved).eql([1]);
      expect(doc.get(['array'])).eql([1, 0, 2, 3, 4]);
    });
    it('can move an item from the begnning to the end of the array', function() {
      var doc = createDoc();
      doc.set(['array'], [0, 1, 2, 3, 4], function() {});
      var moved = doc.move(['array'], 0, 4, 1, function() {});
      expect(moved).eql([0]);
      expect(doc.get(['array'])).eql([1, 2, 3, 4, 0]);
    });
    it('can move several items mid-array, with an event for each', function() {
      var doc = createDoc();
      doc.set(['array'], [0, 1, 2, 3, 4], function() {});
      var moved = doc.move(['array'], 1, 3, 2, function() {});
      expect(moved).eql([1, 2]);
      expect(doc.get(['array'])).eql([0, 3, 4, 1, 2]);
    });
  });
};
