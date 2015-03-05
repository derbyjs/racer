var expect = require('../util').expect;
var Model = require('../../lib/Model');

describe('filter', function() {
  describe('getting', function() {
    it('does not support array', function() {
      var model = (new Model).at('_page');
      model.set('numbers', [0, 3, 4, 1, 2, 3, 0]);
      var filter = model.filter('numbers', function(number, i, numbers) {
        return (number % 2) === 0;
      });
      expect(function() {
        filter.get();
      }).to.throwException();
    });
    it('supports filter of object', function() {
      var model = (new Model).at('_page');
      var numbers = [0, 3, 4, 1, 2, 3, 0];
      for (var i = 0; i < numbers.length; i++) {
        model.set('numbers.' + model.id(), numbers[i]);
      }
      var filter = model.filter('numbers', function(number, id, numbers) {
        return (number % 2) === 0;
      });
      expect(filter.get()).to.eql([0, 4, 2, 0]);
    });
    it('supports sort of object', function() {
      var model = (new Model).at('_page');
      var numbers = [0, 3, 4, 1, 2, 3, 0];
      for (var i = 0; i < numbers.length; i++) {
        model.set('numbers.' + model.id(), numbers[i]);
      }
      var filter = model.sort('numbers', 'asc');
      expect(filter.get()).to.eql([0, 0, 1, 2, 3, 3, 4]);
      filter = model.sort('numbers', 'desc');
      expect(filter.get()).to.eql([4, 3, 3, 2, 1, 0, 0]);
    });
    it('supports filter and sort of object', function() {
      var model = (new Model).at('_page');
      var numbers = [0, 3, 4, 1, 2, 3, 0];
      for (var i = 0; i < numbers.length; i++) {
        model.set('numbers.' + model.id(), numbers[i]);
      }
      model.fn('even', function(number) {
        return (number % 2) === 0;
      });
      var filter = model.filter('numbers', 'even').sort();
      expect(filter.get()).to.eql([0, 0, 2, 4]);
    });
  });
  describe('initial value set by ref', function() {
    it('supports filter of object', function() {
      var model = (new Model).at('_page');
      var numbers = [0, 3, 4, 1, 2, 3, 0];
      for (var i = 0; i < numbers.length; i++) {
        model.set('numbers.' + model.id(), numbers[i]);
      }
      var filter = model.filter('numbers', function(number) {
        return (number % 2) === 0;
      });
      filter.ref('_page.out');
      expect(model.get('out')).to.eql([0, 4, 2, 0]);
    });
    it('supports sort of object', function() {
      var model = (new Model).at('_page');
      var numbers = [0, 3, 4, 1, 2, 3, 0];
      for (var i = 0; i < numbers.length; i++) {
        model.set('numbers.' + model.id(), numbers[i]);
      }
      var filter = model.sort('numbers', 'asc');
      expect(filter.get()).to.eql([0, 0, 1, 2, 3, 3, 4]);
      filter = model.sort('numbers', 'desc');
      filter.ref('_page.out');
      expect(model.get('out')).to.eql([4, 3, 3, 2, 1, 0, 0]);
    });
    it('supports filter and sort of object', function() {
      var model = (new Model).at('_page');
      var numbers = [0, 3, 4, 1, 2, 3, 0];
      for (var i = 0; i < numbers.length; i++) {
        model.set('numbers.' + model.id(), numbers[i]);
      }
      model.fn('even', function(number) {
        return (number % 2) === 0;
      });
      var filter = model.filter('numbers', 'even').sort();
      filter.ref('_page.out');
      expect(model.get('out')).to.eql([0, 0, 2, 4]);
    });
  });
  describe('ref updates as items are modified', function() {
    it('supports filter of object', function() {
      var model = (new Model).at('_page');
      var greenId = model.add('colors', {
        name: 'green',
        primary: true
      });
      var orangeId = model.add('colors', {
        name: 'orange',
        primary: false
      });
      var redId = model.add('colors', {
        name: 'red',
        primary: true
      });
      var filter = model.filter('colors', function(color) {
        return color.primary;
      });
      filter.ref('_page.out');
      expect(model.get('out')).to.eql([
        {
          name: 'green',
          primary: true,
          id: greenId
        }, {
          name: 'red',
          primary: true,
          id: redId
        }
      ]);
      model.set('colors.' + greenId + '.primary', false);
      expect(model.get('out')).to.eql([
        {
          name: 'red',
          primary: true,
          id: redId
        }
      ]);
      var yellowId = model.add('colors', {
        name: 'yellow',
        primary: true
      });
      expect(model.get('out')).to.eql([
        {
          name: 'red',
          primary: true,
          id: redId
        }, {
          name: 'yellow',
          primary: true,
          id: yellowId
        }
      ]);
    });
    it('supports additional dynamic inputs', function() {
      var model = (new Model).at('_page');
      var numbers = [0, 3, 4, 1, 2, 3, 0];
      for (var i = 0; i < numbers.length; i++) {
        model.set('numbers.' + model.id(), numbers[i]);
      }
      model.set('mod', 3);
      model.set('offset', 0);
      var filter = model.filter('numbers', 'mod', 'offset', function(number, id, numbers, mod, offset) {
        return (number % mod) === offset;
      });
      expect(filter.get()).to.eql([0, 3, 3, 0]);
      model.set('offset', 1);
      expect(filter.get()).to.eql([4, 1]);
      model.set('mod', 2);
      expect(filter.get()).to.eql([3, 1, 3]);
    });
  });
});
