var expect, util;

expect = require('../util').expect;

util = require('../../lib/util');

describe('util', function() {
  return describe('util.mergeInto', function() {
    it('merges empty objects', function() {
      var a, b;
      a = {};
      b = {};
      return expect(util.mergeInto(a, b)).to.eql({});
    });
    it('merges an empty object with a populated object', function() {
      var a, b, fn;
      fn = function(x) {
        return x++;
      };
      a = {};
      b = {
        x: 's',
        y: [1, 3],
        fn: fn
      };
      return expect(util.mergeInto(a, b)).to.eql({
        x: 's',
        y: [1, 3],
        fn: fn
      });
    });
    return it('merges a populated object with a populated object', function() {
      var a, b, fn;
      fn = function(x) {
        return x++;
      };
      a = {
        x: 's',
        y: [1, 3],
        fn: fn
      };
      b = {
        x: 7,
        z: {}
      };
      expect(util.mergeInto(a, b)).to.eql({
        x: 7,
        y: [1, 3],
        fn: fn,
        z: {}
      });
      expect(a).to.eql({
        x: 7,
        y: [1, 3],
        fn: fn,
        z: {}
      });
      return expect(b).to.eql({
        x: 7,
        z: {}
      });
    });
  });
});
