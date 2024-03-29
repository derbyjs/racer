var expect = require('../util').expect;
var racer = require('../../lib/index');

describe('bundle', function() {
  it('does not serialize Share docs with null versions and null type', function(done) {
    var backend = racer.createBackend();
    var setupModel = backend.createModel();
    setupModel.add('dogs', {id: 'coco', name: 'Coco'});
    setupModel.whenNothingPending(function() {
      var model1 = backend.createModel({fetchOnly: true});

      // This creates a Share client Doc on the connection, with null version and data.
      model1.connection.get('dogs', 'fido');
      // Fetching a non-existent id results in a Share Doc with version 0 and undefined data.
      model1.fetch('dogs.spot');
      // This doc should be properly fetched and bundled.
      model1.fetch('dogs.coco');

      model1.whenNothingPending(function(err) {
        if (err) return done(err);
        model1.bundle(function(err, bundleData) {
          if (err) return done(err);
          // Simulate serialization of bundle data between server and client.
          bundleData = JSON.parse(JSON.stringify(bundleData));

          var model2 = backend.createModel();
          model2.unbundle(bundleData);
          expect(model2.get('dogs.fido')).to.equal(undefined);
          expect(model2.get('dogs.spot')).to.equal(undefined);
          expect(model2.get('dogs.coco')).to.eql({id: 'coco', name: 'Coco'});
          done();
        });
      });
    });
  });

  it('does not serialize ref outputs', function(done) {
    var backend = racer.createBackend();
    var model = backend.createModel();
    model.add('dogs', {id: 'coco', name: 'Coco'});
    model.ref('_page.myDog', 'dogs.coco');
    model.bundle(function(err, bundleData) {
      if (err) return done(err);
      // Simulate serialization of bundle data between server and client
      bundleData = JSON.parse(JSON.stringify(bundleData));

      // Bundle should not have data duplicated on the ref output path
      expect(bundleData.collections).to.not.have.property('_page');

      // After unbundling, the ref should be re-created
      var clientModel = backend.createModel();
      clientModel.unbundle(bundleData);
      expect(clientModel.get('_page')).to.deep.equal({myDog: {id: 'coco', name: 'Coco'}});
      // Test that operation on ref output path is applied to the backing doc
      clientModel.set('_page.myDog.breed', 'poodle');
      expect(clientModel.get('dogs.coco')).to.deep.equal({id: 'coco', name: 'Coco', breed: 'poodle'});
      done();
    });
  });

  describe('bundlePromised', function() {
    it('awaits bundle completion', async function() {
      var backend = racer.createBackend();
      var model = backend.createModel();
      model.add('dogs', {id: 'coco', name: 'Coco'});
      var bundled = await model.bundlePromised();
      var model2 = backend.createModel();
      model2.unbundle(bundled);
      expect(model2.get('dogs.coco')).to.deep.equal(model.get('dogs.coco'));
    });
  });
});
