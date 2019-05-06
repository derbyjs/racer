var expect = require('../util').expect;
var racer = require('../../lib/index');

describe('unbundle', function() {
  it('dedupes against existing queries', function(done) {
    var backend = racer.createBackend();
    var setupModel = backend.createModel();
    setupModel.add('dogs', {id: 'fido', name: 'Fido'});
    setupModel.whenNothingPending(function() {
      var model1 = backend.createModel({fetchOnly: true});
      var model1Query = model1.query('dogs', {});
      model1.subscribe(model1Query, function() {
        model1.bundle(function(err, bundleData) {
          if (err) {
            return done(err);
          }
          // Simulate serialization of bundle data between server and client.
          bundleData = JSON.parse(JSON.stringify(bundleData));

          var model2 = backend.createModel();
          // Unbundle should load data into model.
          model2.unbundle(bundleData);
          expect(model2.get('dogs.fido.name')).to.eql('Fido');
          // Unloaded data available until after `unloadDelay` ms has elapsed.
          model2.unloadDelay = 4;
          model2.unload();
          expect(model2.get('dogs.fido.name')).to.eql('Fido');
          // Another unbundle should re-increment subscribe count, so the data
          // should still be present even after `unloadDelay` has passed.
          model2.unbundle(bundleData);
          setTimeout(function() {
            expect(model2.get('dogs.fido.name')).to.eql('Fido');
            done();
          }, 8);
        });
      });
    });
  });
});
