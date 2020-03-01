var expect = require('../util').expect;
var racer = require('../../lib/index');

describe('async', function() {
  describe('fetchAsync', function() {
    it('works', function(done) {
      var backend = racer.createBackend();
      var setupModel = backend.createModel();
      setupModel.add('dogs', {id: 'coco', name: 'Coco'});
      setupModel.whenNothingPending(function() {
        var model1 = backend.createModel({fetchOnly: true});
        var promise = model1.fetchAsync('dogs.coco');

        expect(promise).assert(promise instanceof Promise);
        promise.then(function() {
          expect(model1.get('dogs.coco')).to.eql({id: 'coco', name: 'Coco'});
          done();
        });
      });
    });
  });

  describe('unfetchAsync', function() {
    it('works', function(done) {
      var backend = racer.createBackend();
      var setupModel = backend.createModel();
      setupModel.add('dogs', {id: 'coco', name: 'Coco'});
      setupModel.whenNothingPending(function() {
        var model1 = backend.createModel({fetchOnly: true});

        model1.fetchAsync('dogs.coco').then(function() {
          expect(model1.get('dogs.coco')).to.eql({id: 'coco', name: 'Coco'});

          model1.unfetchAsync('dogs.coco').then(function() {
            expect(model1.get('dogs.coco')).to.eql(undefined);
            done();
          });
        });
      });
    });
  });

  describe('subscribeAsync', function() {
    it('works', function(done) {
      var backend = racer.createBackend();
      var setupModel = backend.createModel();
      setupModel.add('dogs', {id: 'coco', name: 'Coco'});
      setupModel.whenNothingPending(function() {
        var model1 = backend.createModel({fetchOnly: true});
        var promise = model1.subscribeAsync('dogs.coco');

        expect(promise).assert(promise instanceof Promise);
        promise.then(function() {
          expect(model1.get('dogs.coco')).to.eql({id: 'coco', name: 'Coco'});
          done();
        });
      });
    });
  });

  describe('unsubscribeAsync', function() {
    it('works', function(done) {
      var backend = racer.createBackend();
      var setupModel = backend.createModel();
      setupModel.add('dogs', {id: 'coco', name: 'Coco'});
      setupModel.whenNothingPending(function() {
        var model1 = backend.createModel({fetchOnly: true});

        model1.subscribeAsync('dogs.coco').then(function() {
          expect(model1.get('dogs.coco')).to.eql({id: 'coco', name: 'Coco'});

          model1.unsubscribeAsync('dogs.coco').then(function() {
            expect(model1.get('dogs.coco')).to.eql(undefined);
            done();
          });
        });
      });
    });
  });

  describe('setAsync', function() {
    it('works', function(done) {
      var backend = racer.createBackend();
      var setupModel = backend.createModel();
      setupModel.add('dogs', {id: 'coco', name: 'Coco'});
      setupModel.whenNothingPending(function() {
        var model1 = backend.createModel({fetchOnly: true});

        model1.fetchAsync('dogs.coco').then(function() {
          model1.setAsync('dogs.coco.name', 'Soso').then(function(prevName) {
            expect(prevName).to.eql('Coco');
            expect(model1.get('dogs.coco')).to.eql({id: 'coco', name: 'Soso'});
            done();
          });
        });
      });
    });
  });

  describe('setDiffAsync', function() {
    it('works', function(done) {
      var backend = racer.createBackend();
      var setupModel = backend.createModel();
      setupModel.add('dogs', {id: 'coco', name: 'Coco'});
      setupModel.whenNothingPending(function() {
        var model1 = backend.createModel({fetchOnly: true});

        model1.fetchAsync('dogs.coco').then(function() {
          model1.setDiffAsync('dogs.coco.name', 'Soso').then(function(prevName) {
            expect(prevName).to.eql('Coco');
            expect(model1.get('dogs.coco')).to.eql({id: 'coco', name: 'Soso'});
            done();
          });
        });
      });
    });
  });

  describe('Queries', function() {
    it('fetchAsync works', function(done) {
      var backend = racer.createBackend();
      var setupModel = backend.createModel();
      setupModel.add('dogs', {id: 'coco', name: 'Coco'});
      setupModel.whenNothingPending(function() {
        var model1 = backend.createModel({fetchOnly: true});
        var query = model1.query('dogs', {name: 'Coco'});
        query.fetchAsync().then(function() {
          expect(query.get()[0]).to.eql({id: 'coco', name: 'Coco'});
          done();
        });
      });
    });

    it('subscribeAsync works', function(done) {
      var backend = racer.createBackend();
      var setupModel = backend.createModel();
      setupModel.add('dogs', {id: 'coco', name: 'Coco'});
      setupModel.whenNothingPending(function() {
        var model1 = backend.createModel({fetchOnly: true});
        var query = model1.query('dogs', {name: 'Coco'});
        query.subscribeAsync().then(function() {
          expect(query.get()[0]).to.eql({id: 'coco', name: 'Coco'});
          done();
        });
      });
    });
  });
});
