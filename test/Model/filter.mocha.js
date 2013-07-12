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
      model.set('numbers', [0, 3, 4, 1, 2, 3, 0]);
      filter = model.filter('numbers', function(number) {
        return (number % 2) === 0;
      });
      filter.ref('_page.out');
      expect(model.get('out')).to.eql([0, 4, 2, 0]);
      model.push('numbers', 6);
      expect(model.get('out')).to.eql([0, 4, 2, 0, 6]);
      model.set('numbers.2', 1);
      expect(model.get('out')).to.eql([0, 2, 0, 6]);
      model.del('numbers');
      expect(model.get('out')).to.eql([]);
      model.set('numbers', [1, 2, 0]);
      return expect(model.get('out')).to.eql([2, 0]);
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
