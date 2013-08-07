var Model, expect;

expect = require('../util').expect;

Model = require('../../lib/Model');

describe('filter', function() {
  describe('getting', function() {
    it('supports filter of array', function() {
      var filter, model;
      model = (new Model).at('_page');
      model.set('numbers', [0, 3, 4, 1, 2, 3, 0]);
      filter = model.filter('numbers', function(number, i, numbers) {
        return (number % 2) === 0;
      });
      return expect(filter.get()).to.eql([0, 4, 2, 0]);
    });

    it('supports sort of array', function() {
      var filter, model;
      model = (new Model).at('_page');
      model.set('numbers', [0, 3, 4, 1, 2, 3, 0]);
      filter = model.sort('numbers');
      expect(filter.get()).to.eql([0, 0, 1, 2, 3, 3, 4]);
      filter = model.sort('numbers', 'asc');
      expect(filter.get()).to.eql([0, 0, 1, 2, 3, 3, 4]);
      filter = model.sort('numbers', 'desc');
      return expect(filter.get()).to.eql([4, 3, 3, 2, 1, 0, 0]);
    });

    it('supports filter and sort of array', function() {
      var filter, model;
      model = (new Model).at('_page');
      model.set('numbers', [0, 3, 4, 1, 2, 3, 0]);
      model.fn('even', function(number) {
        return (number % 2) === 0;
      });
      filter = model.filter('numbers', 'even').sort();
      return expect(filter.get()).to.eql([0, 0, 2, 4]);
    });

    it('supports filter of object', function() {
      var filter, model, number, _i, _len, _ref;
      model = (new Model).at('_page');
      _ref = [0, 3, 4, 1, 2, 3, 0];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        number = _ref[_i];
        model.set('numbers.' + model.id(), number);
      }
      filter = model.filter('numbers', function(number, id, numbers) {
        return (number % 2) === 0;
      });
      return expect(filter.get()).to.eql([0, 4, 2, 0]);
    });

    it('supports sort of object', function() {
      var filter, model, number, _i, _len, _ref;
      model = (new Model).at('_page');
      _ref = [0, 3, 4, 1, 2, 3, 0];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        number = _ref[_i];
        model.set('numbers.' + model.id(), number);
      }
      filter = model.sort('numbers');
      expect(filter.get()).to.eql([0, 0, 1, 2, 3, 3, 4]);
      filter = model.sort('numbers', 'asc');
      expect(filter.get()).to.eql([0, 0, 1, 2, 3, 3, 4]);
      filter = model.sort('numbers', 'desc');
      return expect(filter.get()).to.eql([4, 3, 3, 2, 1, 0, 0]);
    });

    return it('supports filter and sort of object', function() {
      var filter, model, number, _i, _len, _ref;
      model = (new Model).at('_page');
      _ref = [0, 3, 4, 1, 2, 3, 0];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        number = _ref[_i];
        model.set('numbers.' + model.id(), number);
      }
      model.fn('even', function(number) {
        return (number % 2) === 0;
      });
      filter = model.filter('numbers', 'even').sort();
      return expect(filter.get()).to.eql([0, 0, 2, 4]);
    });
  });

  describe('initial value set by ref', function() {
    it('supports filter of array', function() {
      var filter, model;
      model = (new Model).at('_page');
      model.set('numbers', [0, 3, 4, 1, 2, 3, 0]);
      filter = model.filter('numbers', function(number) {
        return (number % 2) === 0;
      });
      filter.ref('_page.out');
      return expect(model.get('out')).to.eql([0, 4, 2, 0]);
    });

    it('supports sort of array', function() {
      var filter, model;
      model = (new Model).at('_page');
      model.set('numbers', [0, 3, 4, 1, 2, 3, 0]);
      filter = model.sort('numbers');
      expect(filter.get()).to.eql([0, 0, 1, 2, 3, 3, 4]);
      filter = model.sort('numbers', 'asc');
      expect(filter.get()).to.eql([0, 0, 1, 2, 3, 3, 4]);
      filter = model.sort('numbers', 'desc');
      filter.ref('_page.out');
      return expect(model.get('out')).to.eql([4, 3, 3, 2, 1, 0, 0]);
    });

    it('supports filter and sort of array', function() {
      var filter, model;
      model = (new Model).at('_page');
      model.set('numbers', [0, 3, 4, 1, 2, 3, 0]);
      model.fn('even', function(number) {
        return (number % 2) === 0;
      });
      filter = model.filter('numbers', 'even').sort();
      filter.ref('_page.out');
      return expect(model.get('out')).to.eql([0, 0, 2, 4]);
    });

    it('supports filter of object', function() {
      var filter, model, number, _i, _len, _ref;
      model = (new Model).at('_page');
      _ref = [0, 3, 4, 1, 2, 3, 0];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        number = _ref[_i];
        model.set('numbers.' + model.id(), number);
      }
      filter = model.filter('numbers', function(number) {
        return (number % 2) === 0;
      });
      filter.ref('_page.out');
      return expect(model.get('out')).to.eql([0, 4, 2, 0]);
    });

    it('supports sort of object', function() {
      var filter, model, number, _i, _len, _ref;
      model = (new Model).at('_page');
      _ref = [0, 3, 4, 1, 2, 3, 0];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        number = _ref[_i];
        model.set('numbers.' + model.id(), number);
      }
      filter = model.sort('numbers');
      expect(filter.get()).to.eql([0, 0, 1, 2, 3, 3, 4]);
      filter = model.sort('numbers', 'asc');
      expect(filter.get()).to.eql([0, 0, 1, 2, 3, 3, 4]);
      filter = model.sort('numbers', 'desc');
      filter.ref('_page.out');
      return expect(model.get('out')).to.eql([4, 3, 3, 2, 1, 0, 0]);
    });

    return it('supports filter and sort of object', function() {
      var filter, model, number, _i, _len, _ref;
      model = (new Model).at('_page');
      _ref = [0, 3, 4, 1, 2, 3, 0];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        number = _ref[_i];
        model.set('numbers.' + model.id(), number);
      }
      model.fn('even', function(number) {
        return (number % 2) === 0;
      });
      filter = model.filter('numbers', 'even').sort();
      filter.ref('_page.out');
      return expect(model.get('out')).to.eql([0, 0, 2, 4]);
    });
  });

  describe('ref updates as items are modified', function() {
    it('supports filter of array', function() {
      var filter, model;
      model = (new Model).at('_page');
      model.set('numbers', [8, 3, 4, 1, 2, 3, 8]);
      filter = model.filter('numbers', function(number) {
        return (number % 2) === 0;
      });
      filter.ref('_page.out');
      expect(model.get('out')).to.eql([8, 4, 2, 8]);
      model.push('numbers', 6); // [8, 3, 4, 1, 2, 3, 8, 6]
      expect(model.get('out')).to.eql([8, 4, 2, 8, 6]);
      model.set('numbers.2', 1); // [8, 3, 1, 1, 2, 3, 8, 6]
      expect(model.get('out')).to.eql([8, 2, 8, 6]);
      model.remove('numbers', 1); // [8, 1, 1, 2, 3, 8, 6]
      expect(model.get('out')).to.eql([8, 2, 8, 6]);
      model.insert('numbers', 1, 1); // [8, 1, 1, 1, 2, 3, 8, 6]
      expect(model.get('out')).to.eql([8, 2, 8, 6]);
      model.remove('numbers', 2, 3); // [8, 1, 3, 8, 6]
      expect(model.get('out')).to.eql([8, 8, 6]);
      model.insert('numbers', 2, [1, 1, 2]); // [8, 1, 1, 1, 2, 3, 8, 6]
      expect(model.get('out')).to.eql([8, 2, 8, 6]);
      model.del('numbers'); // []
      expect(model.get('out')).to.eql([]);
      model.set('numbers', [1, 2, 0]); // [1, 2, 0]
      expect(model.get('out')).to.eql([2, 0]);

      // Highlight issue with one off index-wise in patch fns
      model.del('numbers'); // []
      expect(model.get('out')).to.eql([]);
      model.set('numbers', [0, 1, 2, 3, 4, 5, 6]);  // [0, 1, 2, 3, 4, 5, 6]
      filter.filter(function (number) {
        return (number % 6) !== 0;
      }).update();
      expect(model.get('out')).to.eql([1, 2, 3, 4, 5]);
      model.remove('numbers', 3); // [0, 1, 2, 4, 5, 6]
      expect(model.get('out')).to.eql([1, 2, 4, 5]);
      model.insert('numbers', 3, 3); // [0, 1, 2, 3, 4, 5, 6]
      return expect(model.get('out')).to.eql([1, 2, 3, 4, 5]);
    });

    it('supports filter and sort of array simultaneously', function() {
      var filter, model;
      model = (new Model).at('_page');
      model.set('numbers', [8, 3, 4, 1, 2, 3, 8]);
      filter = model.filter('numbers', function(number) {
        return (number % 2) === 0;
      });
      filter.sort();
      filter.ref('_page.out');
      expect(model.get('out')).to.eql([2, 4, 8, 8]); // [4, 2, 0, 6]
      model.push('numbers', 6); // [8, 3, 4, 1, 2, 3, 8, 6]
      expect(model.get('out')).to.eql([2, 4, 6, 8, 8]); // [4, 2, 0, 6, 7]
      model.set('numbers.2', 1); // [8, 3, 1, 1, 2, 3, 8, 6]
      expect(model.get('out')).to.eql([2, 6, 8, 8]); // [4, 0, 6, 7]
      model.remove('numbers', 1); // [8, 1, 1, 2, 3, 8, 6]
      expect(model.get('out')).to.eql([2, 6, 8, 8]); // [4, 0, 6, 7]
      model.insert('numbers', 1, 1); // [8, 1, 1, 1, 2, 3, 8, 6]
      expect(model.get('out')).to.eql([2, 6, 8, 8]);
      model.remove('numbers', 2, 3); // [8, 1, 3, 8, 6]
      expect(model.get('out')).to.eql([6, 8, 8]);
      model.insert('numbers', 2, [1, 1, 2]); // [8, 1, 1, 1, 2, 3, 8, 6]
      expect(model.get('out')).to.eql([2, 6, 8, 8]);
      model.del('numbers'); // []
      expect(model.get('out')).to.eql([]);
      model.set('numbers', [1, 2, 0]); // [1, 2, 0]
      return expect(model.get('out')).to.eql([0, 2]);
    });

    return it('supports filter of object', function() {
      var filter, greenId, model, orangeId, redId, yellowId;
      model = (new Model).at('_page');
      greenId = model.add('colors', {
        name: 'green',
        primary: true
      });
      orangeId = model.add('colors', {
        name: 'orange',
        primary: false
      });
      redId = model.add('colors', {
        name: 'red',
        primary: true
      });
      filter = model.filter('colors', function(color) {
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
      yellowId = model.add('colors', {
        name: 'yellow',
        primary: true
      });
      return expect(model.get('out')).to.eql([
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
  });

  return describe('possibility to pass along a context (ctx) object', function() {
    it('supports filter of array using ctx', function() {
      var filter, model;
      model = (new Model).at('_page');
      model.set('numbers', [0, 3, 4, 1, 2, 3, 0]);
      model.fn('numbers', function(number, i, numbers, ctx) {
        return (number % ctx.val) === 0;
      });
      filter = model.filter('numbers', 'numbers', {
        val: 2
      });
      return expect(filter.get()).to.eql([0, 4, 2, 0]);
    });

    it('ctx is cloned (i.e. not copied by reference) when updating', function() {
      var filter, model;  
      model = (new Model).at('_page');
      model.set('numbers', [0, 3, 4, 1, 2, 3, 0]);
      model.fn('the5first', function(item, key, item, ctx) {
        if(ctx.i > 5) return false;

        ctx.i++;

        return true;
      });
      filter = model.filter('numbers', 'the5first', {i: 1});
      expect(filter.get()).to.eql([0, 3, 4, 1, 2]); // First time will always be right
      return expect(filter.get()).to.eql([0, 3, 4, 1, 2]); // Second time, if ctx is not cloned, it will not be the same
    });

    return it('supports sort of array using ctx', function() {
      var filter, model;  
      model = (new Model).at('_page');
      model.set('numbers', [0, 3, 4, 1, 2, 3, 0]);
      model.fn('numbers', function(a, b, ctx) {
        var fn
            ;

        if(ctx.reverse) {
          fn = model._namedFns['desc']
        } else {
          fn = model._namedFns['asc']
        }

        return fn(a, b);
      });
      filter = model.sort('numbers', 'numbers');
      expect(filter.get).to.throwError();
      filter = model.sort('numbers', 'numbers', {
        reverse: false
      });
      expect(filter.get()).to.eql([0, 0, 1, 2, 3, 3, 4]);
      filter = model.sort('numbers', 'numbers', {
        reverse: true
      });
      return expect(filter.get()).to.eql([4, 3, 3, 2, 1, 0, 0]);
    });
  });
});
