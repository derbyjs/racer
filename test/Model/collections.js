const {expect} = require('../util');
const {RootModel} = require('../../lib');

describe('collections', () => {
  describe('getValues', () => {
    it('returns array of values from collection', () => {
      const model = new RootModel();
      model.add('_test_docs', {name: 'foo'});
      model.add('_test_docs', {name: 'bar'});

      const values = model.getValues('_test_docs');

      expect(values).to.be.instanceOf(Array);
      expect(values).to.have.lengthOf(2);

      ['foo', 'bar'].forEach((value, index) => {
        expect(values[index]).to.have.property('name', value);
      });
    });

    it('return empty array when no values at subpath', () => {
      const model = new RootModel();

      const values = model.getValues('_test_docs');

      expect(values).to.be.instanceOf(Array);
      expect(values).to.have.lengthOf(0);
    });
  });
});
