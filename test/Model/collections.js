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

    it('returns defult value if null', () => {
      const model = new RootModel();
      const id = model.add('_test_doc', {name: null});
      const defaultValue = 'bar';
      const value = model.getOrDefault(`_test_doc.${id}.name`, defaultValue);
      expect(value).not.to.be.null;
      expect(value).to.equal('bar');
      expect(value).to.eql(defaultValue);
    });
  });

  describe('getOrThrow', () => {
    it('returns value if defined', () => {
      const model = new RootModel();
      model.add('_test_doc', {name: 'foo'});
      const value = model.getOrThrow('_test_doc');
      expect(value).not.to.be.undefined;
    });

    it('throws if value undefined', () => {
      const model = new RootModel();
      expect(() => model.getOrThrow('_test_doc')).to.throw(`No value at path _test_doc`);
      expect(() => model.scope('_test').getOrThrow('doc.1')).to.throw(`No value at path _test.doc.1`);
    });

    it('throws if value null', () => {
      const model = new RootModel();
      const id = model.add('_test_doc', {name: null});
      expect(model.getOrThrow(`_test_doc.${id}`)).to.eql({id, name: null});
      expect(() => model.getOrThrow(`_test_doc.${id}.name`)).to.throw(`No value at path _test_doc`);
    });
  });
});
