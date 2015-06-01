var expect = require('../util').expect;
var Model = require('./MockConnectionModel');

function mutationEvents(createModels) {
  describe('set', function() {
    it('can raise events registered on array indices', function(done) {
      var models = createModels();
      models.local.set('array', [0, 1, 2, 3, 4], function() {});
      models.remote.on('change', 'array.0', function(value, previous) {
        expect(value).to.equal(1);
        expect(previous).to.equal(0);
        done();
      });
      models.local.set('array.0', 1);
    });
  });
  describe('move', function() {
    it('can move an item from the end to the beginning of the array', function(done) {
      var models = createModels();
      models.local.set('array', [0, 1, 2, 3, 4]);
      models.remote.on('move', '**', function(captures, from, to, howMany, passed) {
        expect(from).to.equal(4);
        expect(to).to.equal(0);
        done();
      });
      models.local.move('array', 4, 0, 1);
    });
    it('can swap the first two items in the array', function(done) {
      var models = createModels();
      models.local.set('array', [0, 1, 2, 3, 4], function() {});
      models.remote.on('move', '**', function(captures, from, to, howMany, passed) {
        expect(from).to.equal(1);
        expect(to).to.equal(0);
        done();
      });
      models.local.move('array', 1, 0, 1, function() {});
    });
    it('can move an item from the begnning to the end of the array', function(done) {
      var models = createModels();
      models.local.set('array', [0, 1, 2, 3, 4], function() {});
      models.remote.on('move', '**', function(captures, from, to, howMany, passed) {
        expect(from).to.equal(0);
        expect(to).to.equal(4);
        done();
      });
      models.local.move('array', 0, 4, 1, function() {});
    });
    it('supports a negative destination index of -1 (for last)', function(done) {
      var models = createModels();
      models.local.set('array', [0, 1, 2, 3, 4], function() {});
      models.remote.on('move', '**', function(captures, from, to, howMany, passed) {
        expect(from).to.equal(0);
        expect(to).to.equal(4);
        done();
      });
      models.local.move('array', 0, -1, 1, function() {});
    });
    it('supports a negative source index of -1 (for last)', function(done) {
      var models = createModels();
      models.local.set('array', [0, 1, 2, 3, 4], function() {});
      models.remote.on('move', '**', function(captures, from, to, howMany, passed) {
        expect(from).to.equal(4);
        expect(to).to.equal(2);
        done();
      });
      models.local.move('array', -1, 2, 1, function() {});
    });
    it('can move several items mid-array, with an event for each', function(done) {
      var models = createModels();
      models.local.set('array', [0, 1, 2, 3, 4], function() {});
      var events = 0;
      models.remote.on('move', '**', function(captures, from, to, howMany, passed) {
        expect(from).to.equal(1);
        expect(to).to.equal(4);
        if (++events === 2) {
          done();
        }
      });
      models.local.move('array', 1, 3, 2, function() {});
    });
  });
}

describe('Model events', function() {
  describe('mutator events', function() {
    it('calls earlier listeners in the order of mutations', function(done) {
      var model = (new Model).at('_page');
      var expectedPaths = ['a', 'b', 'c'];
      model.on('change', '**', function(path) {
        expect(path).to.equal(expectedPaths.shift());
        if (!expectedPaths.length) {
          done();
        }
      });
      model.on('change', 'a', function() {
        model.set('b', 2);
      });
      model.on('change', 'b', function() {
        model.set('c', 3);
      });
      model.set('a', 1);
    });
    it('calls later listeners in the order of mutations', function(done) {
      var model = (new Model).at('_page');
      model.on('change', 'a', function() {
        model.set('b', 2);
      });
      model.on('change', 'b', function() {
        model.set('c', 3);
      });
      var expectedPaths = ['a', 'b', 'c'];
      model.on('change', '**', function(path) {
        expect(path).to.equal(expectedPaths.shift());
        if (!expectedPaths.length) {
          done();
        }
      });
      model.set('a', 1);
    });
  });
  describe('remote events', function() {
    function createModels() {
      var localModel = new Model();
      localModel.createConnection();
      var remoteModel = new Model();
      remoteModel.createConnection();
      var localDoc = localModel.getOrCreateDoc('colors', 'green');
      localDoc.create();
      var remoteDoc = remoteModel.getOrCreateDoc('colors', 'green');
      localDoc.shareDoc.on('op', function(op, isLocal) {
        remoteDoc._onOp(op);
      });
      return {
        local: localModel.scope('colors.green'),
        remote: remoteModel.scope('colors.green')
      };
    }
    mutationEvents(createModels);
  });
});
