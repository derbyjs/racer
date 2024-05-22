const {expect} = require('../util');
const {RootModel} = require('../../lib');

describe('collections', () => {
  describe('getOrDefault', () => {
    it('returns value if defined', () => {
      const model = new RootModel();
      model.add('_test_doc', {name: 'foo'});
      const value = model.getOrDefault('_test_doc', {name: 'bar'});
      expect(value).not.to.be.undefined;
    });

    it('returns defuault value if undefined', () => {
      const model = new RootModel();
      const defaultValue = {name: 'bar'};
      const value = model.getOrDefault('_test_doc', defaultValue);
      expect(value).not.to.be.undefined;
      expect(value.name).to.equal('bar');
      expect(value).to.eql(defaultValue);
    });
  });

  describe('getOrThrow', () => {
    it('returns value if defined', () => {
      const model = new RootModel();
      model.add('_test_doc', {name: 'foo'});
      const value = model.getOrThrow('_test_doc', {name: 'bar'});
      expect(value).not.to.be.undefined;
    });

    it('thows if value undefined', () => {
      const model = new RootModel();
      expect(() => model.getOrThrow('_test_doc', {name: 'bar'})).to.throw(`No value at path _test_doc`);
    });
  });
});
