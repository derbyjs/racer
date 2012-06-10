{expect} = require '../util'
{BrowserModel: Model} = require '../util/model'

describe 'In browser queries', ->
  describe 'find', ->
    describe 'among documents under a top-level namespace', ->
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

      it 'should emit insert events on the results refList in response to relevant local mutations', (done) ->
        model =  new Model

        model.set 'users.1', id: '1', age: 20
        model.set 'users.2', userTwo = id: '2', age: 30

        results = model.query('users').where('age').gte(30).find()
        expect(results.get()).to.eql [userTwo]

        model.on 'insert', results.path(), (index, document, out, isLocal) ->
          expect(index).to.equal 1
          expect(document).to.specEql {id: '1', age: 31}
          done()

        model.set 'users.1.age', 31

    describe 'among search results', ->
      it 'should return a scoped model with access to results', ->
        model =  new Model

        model.set 'users.1', userOne = id: '1', age: 30
        model.set 'users.2', userTwo = id: '2', age: 31

        baseResults = model.query('users').where('age').gte(30).find()
        expect(baseResults.get()).to.eql [userOne, userTwo]

        results = model.query(baseResults).where('age').gte(31).find()
        expect(results.get()).to.eql [userTwo]

      it 'should return a scoped model whose results are updated automatically in response to local mutations', ->
        model =  new Model

        model.set 'users.1', userOne = id: '1', age: 30
        model.set 'users.2', userTwo = id: '2', age: 31

        baseResults = model.query('users').where('age').gte(30).find()
        expect(baseResults.get()).to.eql [userOne, userTwo]

        results = model.query(baseResults).where('age').gte(31).find()
        expect(results.get()).to.eql [userTwo]

        model.set 'users.3', userThree = {id: '3', age: 32}
        expect(results.get()).to.eql [userTwo, userThree]

      # Tests transitivity of events across queries over query results
      it 'should emit insert events on the results refList in response to relevant local mutations', (done) ->
        model =  new Model

        model.set 'users.1', userOne = id: '1', age: 30
        model.set 'users.2', userTwo = id: '2', age: 31

        baseResults = model.query('users').where('age').gte(30).find()
        expect(baseResults.get()).to.eql [userOne, userTwo]

        results = model.query(baseResults).where('age').gte(31).find()
        expect(results.get()).to.eql [userTwo]

        model.on 'insert', results.path(), (index, document, out, isLocal) ->
          expect(index).to.equal 1
          expect(document).to.specEql { id: '3', age: 32 }
          done()

        model.set 'users.3', userThree = {id: '3', age: 32}
