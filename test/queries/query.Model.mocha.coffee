{expect} = require '../util'
{BrowserModel: Model} = require '../util/model'

describe 'In browser queries', ->
  describe 'find', ->
    it 'should return a scoped model with access to results', ->
      model =  new Model

      model.set 'users.1', id: '1', age: 20
      model.set 'users.2', userTwo = id: '2', age: 30

      results = model.query('users').where('age').gte(30).find()
      expect(results.get()).to.eql [userTwo]

    it 'should return a scoped model whose results are updated automatically in response to local mutations', ->
      model =  new Model

      model.set 'users.1', id: '1', age: 20
      model.set 'users.2', userTwo = id: '2', age: 30

      results = model.query('users').where('age').gte(30).find()
      expect(results.get()).to.eql [userTwo]
      model.set 'users.1.age', 31
      expect(results.get()).to.specEql [userTwo, {id: '1', age: 31}]
