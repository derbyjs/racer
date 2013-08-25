var Model, expect;

expect = require('../util').expect;

Model = require('../../lib/Model');

describe('refList', function() {
  var expectEvents, expectFromEvents, expectArrayFromEvents, expectIdsEvents, expectToEvents, setup;
  setup = function(options, array) {
    var model;
    model = (new Model).at('_page');
    if(!array) {
      model.set('colors', {
        green: {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        },
        red: {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      });
      model.set('ids', ['red', 'green', 'red']);
      model.refList('list', 'colors', 'ids', options);
    } else {      
      model.set('array', ['a', 'b']);
      model.set('arrayIds', [0, 1]);
      model.refList('arrayList', 'array', 'arrayIds', options);
    }
    return model;
  };
  expectEvents = function(pattern, model, done, events) {
    model.on('all', pattern, function() {
      events.shift().apply(null, arguments);
      if (!events.length) {
        return done();
      }
    });
    if (!(events != null ? events.length : void 0)) {
      return done();
    }
  };
  expectFromEvents = function(model, done, events) {
    return expectEvents('list**', model, done, events);
  };
  expectArrayFromEvents = function(model, done, events) {
    return expectEvents('arrayList**', model, done, events);
  };
  expectToEvents = function(model, done, events) {
    return expectEvents('colors**', model, done, events);
  };
  expectIdsEvents = function(model, done, events) {
    return expectEvents('ids**', model, done, events);
  };
  describe('sets output on initial call', function() {
    it('sets the initial value to empty array if no inputs', function() {
      var model;
      model = (new Model).at('_page');
      model.refList('empty', 'colors', 'noIds');
      return expect(model.get('empty')).to.eql([]);
    });
    return it('sets the initial value for already populated data', function() {
      var model;
      model = setup();
      return expect(model.get('list')).to.eql([
        {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      ]);
    });
  });
  describe('updates on `ids` mutations', function() {
    it('updates the value when `ids` is set', function() {
      var model;
      model = (new Model).at('_page');
      model.set('colors', {
        green: {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        },
        red: {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      });
      model.refList('list', 'colors', 'ids');
      expect(model.get('list')).to.eql([]);
      model.set('ids', ['red', 'green', 'red']);
      return expect(model.get('list')).to.eql([
        {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      ]);
    });
    it('emits on `from` when `ids` is set', function(done) {
      var model;
      model = (new Model).at('_page');
      model.set('colors', {
        green: {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        },
        red: {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      });
      model.refList('list', 'colors', 'ids');
      model.on('all', 'list**', function(capture, method, index, values) {
        expect(capture).to.equal('');
        expect(method).to.equal('insert');
        expect(index).to.equal(0);
        expect(values).to.eql([
          {
            id: 'red',
            rgb: [255, 0, 0],
            hex: '#f00'
          }, {
            id: 'green',
            rgb: [0, 255, 0],
            hex: '#0f0'
          }, {
            id: 'red',
            rgb: [255, 0, 0],
            hex: '#f00'
          }
        ]);
        return done();
      });
      return model.set('ids', ['red', 'green', 'red']);
    });
    it('updates the value when `ids` children are set', function() {
      var model;
      model = setup();
      model.set('ids.0', 'green');
      expect(model.get('list')).to.eql([
        {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      ]);
      model.set('ids.2', 'blue');
      return expect(model.get('list')).to.eql([
        {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, void 0
      ]);
    });
    it('emits on `from` when `ids` children are set', function(done) {
      var model;
      model = setup();
      model.on('all', 'list**', function(capture, method, value, previous) {
        expect(capture).to.equal('2');
        expect(method).to.equal('change');
        expect(value).to.eql({
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        });
        expect(previous).to.eql({
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        });
        return done();
      });
      return model.set('ids.2', 'green');
    });
    it('updates the value when `ids` are inserted', function() {
      var model;
      model = setup();
      model.push('ids', 'green');
      expect(model.get('list')).to.eql([
        {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }
      ]);
      model.insert('ids', 1, ['blue', 'red']);
      return expect(model.get('list')).to.eql([
        {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, void 0, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }
      ]);
    });
    it('emits on `from` when `ids` are inserted', function(done) {
      var model;
      model = setup();
      model.on('all', 'list**', function(capture, method, index, inserted) {
        expect(capture).to.equal('');
        expect(method).to.equal('insert');
        expect(index).to.equal(1);
        expect(inserted).to.eql([
          void 0, {
            id: 'red',
            rgb: [255, 0, 0],
            hex: '#f00'
          }
        ]);
        return done();
      });
      return model.insert('ids', 1, ['blue', 'red']);
    });
    it('updates the value when `ids` are removed', function() {
      var model;
      model = setup();
      model.pop('ids');
      expect(model.get('list')).to.eql([
        {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }
      ]);
      model.remove('ids', 0, 2);
      return expect(model.get('list')).to.eql([]);
    });
    it('emits on `from` when `ids` are removed', function(done) {
      var model;
      model = setup();
      model.on('all', 'list**', function(capture, method, index, removed) {
        expect(capture).to.equal('');
        expect(method).to.equal('remove');
        expect(index).to.equal(0);
        expect(removed).to.eql([
          {
            id: 'red',
            rgb: [255, 0, 0],
            hex: '#f00'
          }, {
            id: 'green',
            rgb: [0, 255, 0],
            hex: '#0f0'
          }
        ]);
        return done();
      });
      return model.remove('ids', 0, 2);
    });
    it('updates the value when `ids` are moved', function() {
      var model;
      model = setup();
      model.move('ids', 0, 2, 2);
      expect(model.get('list')).to.eql([
        {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }
      ]);
      model.move('ids', 2, 0);
      return expect(model.get('list')).to.eql([
        {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      ]);
    });
    return it('emits on `from` when `ids` are moved', function(done) {
      var model;
      model = setup();
      model.on('all', 'list**', function(capture, method, from, to, howMany) {
        expect(capture).to.equal('');
        expect(method).to.equal('move');
        expect(from).to.equal(0);
        expect(to).to.equal(2);
        expect(howMany).to.eql(2);
        return done();
      });
      return model.move('ids', 0, 2, 2);
    });
  });
  describe('emits events involving multiple refLists', function() {
    return it('removes data from a refList pointing to data in another refList', function() {
      var id, model, tagId, tagIds;
      model = (new Model).at('_page');
      tagId = model.add('tags', {
        text: 'hi'
      });
      tagIds = [tagId];
      id = model.add('profiles', {
        tagIds: tagIds
      });
      model.push('profileIds', id);
      model.refList('profilesList', 'profiles', 'profileIds');
      model.ref('profile', 'profilesList.0');
      model.refList('tagsList', 'tags', 'profile.tagIds');
      return model.remove('tagsList', 0);
    });
  });
  describe('updates on `to` mutations', function() {
    it('updates the value when `to` is set', function() {
      var model;
      model = (new Model).at('_page');
      model.set('ids', ['red', 'green', 'red']);
      model.refList('list', 'colors', 'ids');
      expect(model.get('list')).to.eql([void 0, void 0, void 0]);
      model.set('colors', {
        green: {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        },
        red: {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      });
      return expect(model.get('list')).to.eql([
        {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      ]);
    });
    it('emits on `from` when `to` is set', function(done) {
      var model;
      model = (new Model).at('_page');
      model.set('ids', ['red', 'green', 'red']);
      model.refList('list', 'colors', 'ids');
      expectFromEvents(model, done, [
        function(capture, method, index, removed) {
          expect(capture).to.equal('');
          expect(method).to.equal('remove');
          expect(index).to.equal(0);
          return expect(removed).to.eql([void 0, void 0, void 0]);
        }, function(capture, method, index, inserted) {
          expect(capture).to.equal('');
          expect(method).to.equal('insert');
          expect(index).to.equal(0);
          return expect(inserted).to.eql([
            {
              id: 'red',
              rgb: [255, 0, 0],
              hex: '#f00'
            }, {
              id: 'green',
              rgb: [0, 255, 0],
              hex: '#0f0'
            }, {
              id: 'red',
              rgb: [255, 0, 0],
              hex: '#f00'
            }
          ]);
        }
      ]);
      return model.set('colors', {
        green: {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        },
        red: {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      });
    });
    it('updates the value when `to` children are set', function() {
      var model;
      model = (new Model).at('_page');
      model.set('ids', ['red', 'green', 'red']);
      model.refList('list', 'colors', 'ids');
      model.set('colors.green', {
        id: 'green',
        rgb: [0, 255, 0],
        hex: '#0f0'
      });
      expect(model.get('list')).to.eql([
        void 0, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, void 0
      ]);
      model.set('colors.red', {
        id: 'red',
        rgb: [255, 0, 0],
        hex: '#f00'
      });
      expect(model.get('list')).to.eql([
        {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      ]);
      model.del('colors.green');
      return expect(model.get('list')).to.eql([
        {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, void 0, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      ]);
    });
    it('emits on `from` when `to` children are set', function(done) {
      var model;
      model = (new Model).at('_page');
      model.set('ids', ['red', 'green', 'red']);
      model.refList('list', 'colors', 'ids');
      expectFromEvents(model, done, [
        function(capture, method, value, previous) {
          expect(capture).to.equal('0');
          expect(method).to.equal('change');
          expect(value).to.eql({
            id: 'red',
            rgb: [255, 0, 0],
            hex: '#f00'
          });
          return expect(previous).to.equal(void 0);
        }, function(capture, method, value, previous) {
          expect(capture).to.equal('2');
          expect(method).to.equal('change');
          expect(value).to.eql({
            id: 'red',
            rgb: [255, 0, 0],
            hex: '#f00'
          });
          return expect(previous).to.equal(void 0);
        }
      ]);
      return model.set('colors.red', {
        id: 'red',
        rgb: [255, 0, 0],
        hex: '#f00'
      });
    });
    it('updates the value when `to` descendants are set', function() {
      var model;
      model = setup();
      model.set('colors.red.hex', '#e00');
      expect(model.get('list')).to.eql([
        {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#e00'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#e00'
        }
      ]);
      model.set('colors.red.rgb.0', 238);
      return expect(model.get('list')).to.eql([
        {
          id: 'red',
          rgb: [238, 0, 0],
          hex: '#e00'
        }, {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'red',
          rgb: [238, 0, 0],
          hex: '#e00'
        }
      ]);
    });
    it('emits on `from` when `to` descendants are set', function(done) {
      var model;
      model = setup();
      expectFromEvents(model, done, [
        function(capture, method, value, previous) {
          expect(capture).to.equal('0.hex');
          expect(method).to.equal('change');
          expect(value).to.eql('#e00');
          return expect(previous).to.equal('#f00');
        }, function(capture, method, value, previous) {
          expect(capture).to.equal('2.hex');
          expect(method).to.equal('change');
          expect(value).to.eql('#e00');
          return expect(previous).to.equal('#f00');
        }, function(capture, method, value, previous) {
          expect(capture).to.equal('0.rgb.0');
          expect(method).to.equal('change');
          expect(value).to.eql(238);
          return expect(previous).to.equal(255);
        }, function(capture, method, value, previous) {
          expect(capture).to.equal('2.rgb.0');
          expect(method).to.equal('change');
          expect(value).to.eql(238);
          return expect(previous).to.equal(255);
        }
      ]);
      model.set('colors.red.hex', '#e00');
      return model.set('colors.red.rgb.0', 238);
    });
    it('updates the value when inserting on `to` children', function() {
      var model;
      model = (new Model).at('_page');
      model.set('nums', {
        even: [2, 4, 6],
        odd: [1, 3]
      });
      model.set('ids', ['even', 'odd', 'even']);
      model.refList('list', 'nums', 'ids');
      expect(model.get('list')).to.eql([[2, 4, 6], [1, 3], [2, 4, 6]]);
      model.push('nums.even', 8);
      return expect(model.get('list')).to.eql([[2, 4, 6, 8], [1, 3], [2, 4, 6, 8]]);
    });
    return it('emits on `from` when inserting on `to` children', function(done) {
      var model;
      model = (new Model).at('_page');
      model.set('nums', {
        even: [2, 4, 6],
        odd: [1, 3]
      });
      model.set('ids', ['even', 'odd', 'even']);
      model.refList('list', 'nums', 'ids');
      expectFromEvents(model, done, [
        function(capture, method, index, inserted) {
          expect(capture).to.equal('0');
          expect(method).to.equal('insert');
          expect(index).to.equal(3);
          return expect(inserted).to.eql([8]);
        }, function(capture, method, index, inserted) {
          expect(capture).to.equal('2');
          expect(method).to.equal('insert');
          expect(index).to.equal(3);
          return expect(inserted).to.eql([8]);
        }
      ]);
      return model.push('nums.even', 8);
    });
  });
  describe('updates on `from` mutations', function() {
    it('updates `to` and `ids` when `from` is set', function() {
      var model;
      model = setup();
      model.set('list', [
        {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      ]);
      expect(model.get('ids')).to.eql(['green', 'red']);
      expect(model.get('colors')).to.eql({
        green: {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        },
        red: {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      });
      model.del('list');
      expect(model.get('ids')).to.eql([]);
      expect(model.get('colors')).to.eql({
        green: {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        },
        red: {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      });
      model.set('list', [
        {
          id: 'blue',
          rgb: [0, 0, 255],
          hex: '#00f'
        }, {
          id: 'yellow',
          rgb: [255, 255, 0],
          hex: '#ff0'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      ]);
      expect(model.get('ids')).to.eql(['blue', 'yellow', 'red']);
      expect(model.get('colors')).to.eql({
        green: {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        },
        red: {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        },
        blue: {
          id: 'blue',
          rgb: [0, 0, 255],
          hex: '#00f'
        },
        yellow: {
          id: 'yellow',
          rgb: [255, 255, 0],
          hex: '#ff0'
        }
      });
      model.at('list.0').remove();
      expect(model.get('ids')).to.eql(['yellow', 'red']);
      return expect(model.get('colors')).to.eql({
        green: {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        },
        red: {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        },
        blue: {
          id: 'blue',
          rgb: [0, 0, 255],
          hex: '#00f'
        },
        yellow: {
          id: 'yellow',
          rgb: [255, 255, 0],
          hex: '#ff0'
        }
      });
    });
    it('emits on `to` when `from` is set', function(done) {
      var model;
      model = setup();
      expectToEvents(model, done, [
        function(capture, method, value, previous) {
          expect(capture).to.equal('blue');
          expect(method).to.equal('change');
          expect(value).to.eql({
            id: 'blue',
            rgb: [0, 0, 255],
            hex: '#00f'
          });
          return expect(previous).to.eql(void 0);
        }, function(capture, method, value, previous) {
          expect(capture).to.equal('yellow');
          expect(method).to.equal('change');
          expect(value).to.eql({
            id: 'yellow',
            rgb: [255, 255, 0],
            hex: '#ff0'
          });
          return expect(previous).to.eql(void 0);
        }
      ]);
      return model.set('list', [
        {
          id: 'blue',
          rgb: [0, 0, 255],
          hex: '#00f'
        }, model.get('colors.red'), {
          id: 'yellow',
          rgb: [255, 255, 0],
          hex: '#ff0'
        }
      ]);
    });
    it('emits on `ids` when `from is set', function(done) {
      var model;
      model = setup();
      expectIdsEvents(model, done, [
        function(capture, method, value, previous) {
          expect(capture).to.equal('');
          expect(method).to.equal('change');
          expect(value).to.eql(['blue', 'red', 'yellow']);
          return expect(previous).to.eql(['red', 'green', 'red']);
        }
      ]);
      return model.set('list', [
        {
          id: 'blue',
          rgb: [0, 0, 255],
          hex: '#00f'
        }, {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }, {
          id: 'yellow',
          rgb: [255, 255, 0],
          hex: '#ff0'
        }
      ]);
    });
    it('emits nothing on `to` when `from` is set, removing items', function(done) {
      var model;
      model = setup();
      expectToEvents(model, done, []);
      return model.set('list', []);
    });
    it('creates a document in `to` on an insert', function() {
      var model;
      model = setup();
      model.insert('list', 0, {
        id: 'yellow'
      });
      return expect(model.get('colors.yellow')).to.eql({
        id: 'yellow'
      });
    });
    return it('creates a document in `to` on an insert of a doc with no id', function() {
      var model, newId;
      model = setup();
      model.insert('list', 0, {
        rgb: [1, 1, 1]
      });
      newId = model.get('list.0').id;
      return expect(model.get("colors." + newId)).to.eql({
        id: newId,
        rgb: [1, 1, 1]
      });
    });
  });
  describe('event ordering', function() {
    return it('should be able to resolve a non-existent nested property as undefined, inside an event listener on refA (where refA -> refList)', function(done) {
      var model;
      model = setup();
      model.refList('array', 'colors', 'arrayIds');
      model.ref('arrayAlias', 'array');
      model.on('insert', 'arrayAlias', function() {
        expect(model.get('array.0.names.0')).to.eql(void 0);
        return done();
      });
      model.insert('arrayAlias', 0, {
        rgb: [1, 1, 1]
      });
      return expect(model.get('arrayIds')).to.have.length(1);
    });
  });
  describe('deleteRemoved', function() {
    return it('deletes the underlying object when an item is removed', function() {
      var model;
      model = setup({
        deleteRemoved: true
      });
      expect(model.get('colors')).to.eql({
        green: {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        },
        red: {
          id: 'red',
          rgb: [255, 0, 0],
          hex: '#f00'
        }
      });
      model.remove('list', 0);
      return expect(model.get('colors')).to.eql({
        green: {
          id: 'green',
          rgb: [0, 255, 0],
          hex: '#0f0'
        }
      });
    });
  });
  return describe('arrays', function() {
    return it('update on set', function(done) {
      var model = setup({}, true);
      expectArrayFromEvents(model, done, [
        function(capture, method, value, previous) {
          expect(method).to.equal('change');
          expect(value).to.equal('c');
          return expect(previous).to.equal('a');
        }
      ]);
      return model.set('array.0', 'c');
    });
  });
});
