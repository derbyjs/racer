var expect = require('../util').expect;
var util = require('../../lib/util');

describe('util', function() {
  describe('util.mergeInto', function() {
    it('merges empty objects', function() {
      var a = {};
      var b = {};
      expect(util.mergeInto(a, b)).to.eql({});
    });

    it('merges an empty object with a populated object', function() {
      var fn = function(x) {
        return x++;
      };
      var a = {};
      var b = {x: 's', y: [1, 3], fn: fn};
      expect(util.mergeInto(a, b)).to.eql({x: 's', y: [1, 3], fn: fn});
    });

    it('merges a populated object with a populated object', function() {
      var fn = function(x) {
        return x++;
      };
      var a = {x: 's', y: [1, 3], fn: fn};
      var b = {x: 7, z: {}};
      expect(util.mergeInto(a, b)).to.eql({x: 7, y: [1, 3], fn: fn, z: {}});
      // Merge should modify the first argument
      expect(a).to.eql({x: 7, y: [1, 3], fn: fn, z: {}});
      // But not the second
      expect(b).to.eql({x: 7, z: {}});
    });
  });
});
