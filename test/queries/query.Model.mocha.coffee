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

    describe 'among documents under a nested path', ->
      describe 'organized in an Object', ->
        it 'should return a scoped model with access to results', ->
          model =  new Model

          model.set 'a.b.c.A', id: 'A', age: 20
          model.set 'a.b.c.B', docB = id: 'B', age: 30

          results = model.query('a.b.c').where('age').gte(30).find()
          expect(results.get()).to.eql [docB]

        it 'should return a scoped model whose results are updated automatically in response to local mutations', ->
          model =  new Model

          model.set 'a.b.c.A', id: 'A', age: 20
          model.set 'a.b.c.B', docB = id: 'B', age: 30

          results = model.query('a.b.c').where('age').gte(30).find()
          expect(results.get()).to.eql [docB]
          model.set 'a.b.c.A.age', 31
          expect(results.get()).to.specEql [docB, {id: 'A', age: 31}]

        it 'should emit insert events on the results refList in response to relevant local mutations', (done) ->
          model =  new Model

          model.set 'a.b.c.A', id: 'A', age: 20
          model.set 'a.b.c.B', docB = id: 'B', age: 30

          results = model.query('a.b.c').where('age').gte(30).find()
          expect(results.get()).to.eql [docB]

          model.on 'insert', results.path(), (index, document, out, isLocal) ->
            expect(index).to.equal 1
            expect(document).to.specEql {id: 'A', age: 31}
            done()

          model.set 'a.b.c.A.age', 31

      describe 'organized in an Array', ->
        it 'should return a scoped model with access to results', ->
          model =  new Model

          model.set 'a.b.c', [
            { id: 'A', age: 20 }
          , docB = { id: 'B', age: 30 }
          ]

          results = model.query('a.b.c').where('age').gte(30).find()
          expect(results.get()).to.eql [docB]

        it 'should return a scoped model whose results are updated automatically in response to local mutations', ->
          model =  new Model

          model.set 'a.b.c', [
            { id: 'A', age: 20 }
          , docB = { id: 'B', age: 30 }
          ]

          results = model.query('a.b.c').where('age').gte(30).find()
          expect(results.get()).to.eql [docB]
          model.set 'a.b.c.0.age', 31
          expect(results.get()).to.specEql [docB, {id: 'A', age: 31}]

        it 'should emit insert events on the results refList in response to relevant local mutations', (done) ->
          model =  new Model

          model.set 'a.b.c', [
            { id: 'A', age: 20 }
          , docB = { id: 'B', age: 30 }
          ]

          results = model.query('a.b.c').where('age').gte(30).find()
          expect(results.get()).to.eql [docB]

          model.on 'insert', results.path(), (index, document, out, isLocal) ->
            expect(index).to.equal 1
            expect(document).to.specEql {id: 'A', age: 31}
            done()

          model.set 'a.b.c.0.age', 31

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

  describe 'findOne', ->
    describe 'among documents under a top-level namespace', ->
      it 'should return a scoped model with access to the result', ->
        model = new Model

        model.set 'users.1', userOne = id: '1', age: 21
        model.set 'users.2', id: '2', age: 22

        result = model.query('users').where('age').gte(21).findOne()
        expect(result.get()).to.eql userOne

      it 'should return a scoped model whose result is updated automatically in response to local mutations', ->
        model = new Model

        model.set 'users.1', userOne = id: '1', age: 31
        model.set 'users.2', id: '2', age: 21

        result = model.query('users').where('age').gte(30).sort(['age', 'asc']).findOne()
        expect(result.get()).to.eql userOne
        model.set 'users.2.age', 30
        expect(result.get()).to.specEql {id: '2', age: 30 }

      it 'should emit set events on the result ref in response to relevant local mutations', (done) ->
        model = new Model

        model.set 'users.1', userOne = id: '1', age: 31
        model.set 'users.2', id: '2', age: 21

        result = model.query('users').where('age').gte(30).sort(['age', 'asc']).findOne()
        expect(result.get()).to.eql userOne

        model.on 'set', result.path(), (document, isLocal) ->
          expect(document).to.specEql {id: '2', age: 30}
          done()

        model.set 'users.2.age', 30

    describe 'among documents under a nested path', ->
      describe 'organized in an Object', ->
        it 'should return a scoped model with access to result', ->
          model = new Model

          model.set 'a.b.c.A', docA = id: 'A', age: 21
          model.set 'a.b.c.B', id: 'B', age: 22

          result = model.query('a.b.c').where('age').gte(21).findOne()
          expect(result.get()).to.eql docA

        it 'should return a scoped model whose result is updated automatically in response to local mutations', ->
          model = new Model

          model.set 'a.b.c.A', docA = id: 'A', age: 31
          model.set 'a.b.c.B', id: 'B', age: 21

          result = model.query('a.b.c').where('age').gte(30).sort(['age', 'asc']).findOne()
          expect(result.get()).to.eql docA
          model.set 'a.b.c.B.age', 30
          expect(result.get()).to.specEql {id: 'B', age: 30 }

        it 'should emit insert events on the result ref in response to relevant local mutations', (done) ->
          model = new Model

          model.set 'a.b.c.A', docA = id: 'A', age: 31
          model.set 'a.b.c.B', id: 'B', age: 21

          result = model.query('a.b.c').where('age').gte(30).sort(['age', 'asc']).findOne()
          expect(result.get()).to.eql docA

          model.on 'set', result.path(), (document, isLocal) ->
            expect(document).to.specEql {id: 'B', age: 30}
            done()

          model.set 'a.b.c.B.age', 30

      describe 'organized in an Array', ->
        it 'should return a scoped model with access to result', ->
          model = new Model

          model.set 'a.b.c', [
            docA = {id: 'A', age: 21}
            {id: 'B', age: 22}
          ]

          result = model.query('a.b.c').where('age').gte(21).sort(['age', 'asc']).findOne()
          expect(result.get()).to.eql docA

        it 'should return a scoped model whose result is updated automatically in response to local mutations', ->
          model = new Model

          model.set 'a.b.c', [
            docA = {id: 'A', age: 31}
            {id: 'B', age: 22}
          ]

          result = model.query('a.b.c').where('age').gte(30).sort(['age', 'asc']).findOne()
          expect(result.get()).to.eql docA
          model.set 'a.b.c.1.age', 30
          expect(result.get()).to.specEql {id: 'B', age: 30 }

        it 'should emit insert events on the results refList in response to relevant local mutations', (done) ->
          model = new Model

          model.set 'a.b.c', [
            docA = {id: 'A', age: 31}
            {id: 'B', age: 22}
          ]

          result = model.query('a.b.c').where('age').gte(30).sort(['age', 'asc']).findOne()
          expect(result.get()).to.eql docA

          model.on 'set', result.path(), (document, isLocal) ->
            expect(document).to.specEql {id: 'B', age: 30}
            done()

          model.set 'a.b.c.1.age', 30

    describe 'among search results', ->
      it 'should return a scoped model with access to result', ->
        model =  new Model

        model.set 'users.1', userOne = id: '1', age: 30
        model.set 'users.2', userTwo = id: '2', age: 31

        baseResults = model.query('users').where('age').gte(30).find()
        expect(baseResults.get()).to.eql [userOne, userTwo]

        result = model.query(baseResults).where('age').gte(31).sort(['age', 'asc']).findOne()
        expect(result.get()).to.eql userTwo

      it 'should return a scoped model whose result is updated automatically in response to local mutations', ->
        model =  new Model

        model.set 'users.1', userOne = id: '1', age: 30
        model.set 'users.2', userTwo = id: '2', age: 32

        baseResults = model.query('users').where('age').gte(30).find()
        expect(baseResults.get()).to.eql [userOne, userTwo]

        result = model.query(baseResults).where('age').gte(31).sort(['age', 'asc']).findOne()
        expect(result.get()).to.eql userTwo

        model.set 'users.3', userThree = {id: '3', age: 31}
        expect(result.get()).to.eql userThree

      # Tests transitivity of events across queries over query results
      it 'should emit insert events on the results refList in response to relevant local mutations', (done) ->
        model =  new Model

        model.set 'users.1', userOne = id: '1', age: 30
        model.set 'users.2', userTwo = id: '2', age: 32

        baseResults = model.query('users').where('age').gte(30).find()
        expect(baseResults.get()).to.eql [userOne, userTwo]

        result = model.query(baseResults).where('age').gte(31).sort(['age', 'asc']).findOne()
        expect(result.get()).to.eql userTwo

        model.on 'set', result.path(), (document, isLocal) ->
          expect(document).to.specEql { id: '3', age: 31 }
          done()

        model.set 'users.3', userThree = {id: '3', age: 31}

# TODO Add test to throw error if you forget to specify a sort on findOne
