{expect} = require '../util'
{finishAfter} = require '../../lib/util/async'
{mockFullSetup} = require '../util/model'
QueryBuilder = require '../../lib/descriptor/query/QueryBuilder'
sinon = require 'sinon'

makeQuery = (ns) -> new QueryBuilder({from: ns})

module.exports = (plugins) ->
  describe 'subscribe', ->
    storeId = 1
    test = ({initialDoc, queries, withStore, preCondition, postCondition, mutate, listenForMutation}) ->
      return (done) ->
        {store} = testContext = this
        withStore.call testContext, store
        mockFullSetup store, done, plugins, (modelA, modelB, done) ->
          [key, doc] = initialDoc.call testContext
          store.set key, doc, null, ->
            listenForMutation.call testContext, modelA, ->
              postCondition.call testContext, modelA
              done()
            modelA.subscribe queries.call(testContext, modelA.query.bind(modelA))..., ->
              preCondition.call testContext, modelA
              mutate.call testContext, modelB

    describe 'set <namespace>.<id>', ->
      it 'should publish the txn *only* to relevant live `equals` queries', (done) ->
        userLeo  = id: '1', name: 'leo'
        userBill = id: '2', name: 'bill'
        userSue  = id: '3', name: 'sue'

        {store, currNs} = this
        store.query.expose currNs, 'withName', (name) -> @where('name').equals(name)
        mockFullSetup store, done, plugins, (modelLeo, modelBill, done) ->
          finish = finishAfter 2, ->
            modelSue = store.createModel()
            modelSue.set "#{currNs}.1", userLeo
            modelSue.set "#{currNs}.2", userBill
            modelSue.set "#{currNs}.3", userSue
            done()

          queryLeo = modelLeo.query(currNs).withName('leo')
          modelLeo.subscribe queryLeo, ->
            modelLeo.on 'set', "#{currNs}.1", (user) ->
              expect(user).to.eql userLeo
            finish()

          queryBill = modelBill.query(currNs).withName('bill')
          modelBill.subscribe queryBill, ->
            modelBill.on 'set', "#{currNs}.2", (user) ->
              expect(user).to.eql userBill
            finish()

      describe 'remotely', ->
        it 'should update the relevant query results alias', (done) ->
          {store, currNs} = this
          docOne = id: '1', age: 20
          docTwo = id: '2', age: 30
          docThree = id: '3', age: 25
          store.query.expose currNs, 'adultsYoungToOld', ->
            @where('age').gte(20).sort('age', 'asc')
          mockFullSetup store, done, plugins, (modelA, modelB, done) ->
            store.set "#{currNs}.1", docOne, null, ->
              store.set "#{currNs}.2", docTwo, null, ->
                modelA.subscribe modelA.query(currNs).adultsYoungToOld(), (err, results) ->
                  expect(results.get()).to.eql [docOne, docTwo]
                  results.on 'insert', ->
                    expect(results.get()).to.eql [docOne, docThree, docTwo]
                    done()
                  modelB.set "#{currNs}.3", docThree

      describe 'locally', ->
        it 'should update the relevant query results alias', (done) ->
          {store, currNs} = this
          docOne = id: '1', age: 20
          docTwo = id: '2', age: 30
          docThree = id: '3', age: 25
          store.query.expose currNs, 'adultsYoungToOld', ->
            @where('age').gte(20).sort('age', 'asc')
          mockFullSetup store, done, plugins, (modelA, done) ->
            store.set "#{currNs}.1", docOne, null, ->
              store.set "#{currNs}.2", docTwo, null, ->
                modelA.subscribe modelA.query(currNs).adultsYoungToOld(), (err, results) ->
                  expect(results.get()).to.eql [docOne, docTwo]
                  results.on 'insert', ->
                    expect(results.get()).to.eql [docOne, docThree, docTwo]
                    done()
                  modelA.set "#{currNs}.3", docThree

      it 'should emit insert events on the refList of relevant query results for a new addition to the result set', (done) ->
        {store, currNs} = this
        docOne = id: '1', age: 20
        docTwo = id: '2', age: 30
        docThree = id: '3', age: 25
        store.query.expose currNs, 'adultsYoungToOld', ->
          @where('age').gte(20).sort('age', 'asc')
        mockFullSetup store, done, plugins, (modelA, modelB, done) ->
          store.set "#{currNs}.1", docOne, null, ->
            store.set "#{currNs}.2", docTwo, null, ->
              modelA.subscribe modelA.query(currNs).adultsYoungToOld(), (err, results) ->
                expect(results.get()).to.eql [docOne, docTwo]
                results.on 'insert', ->
                  done()
                modelB.set "#{currNs}.3", docThree

    describe 'set <namespace>.<id>.*', ->
      describe 'for equals queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', greeting: 'foo'}]
          withStore: (store) ->
            store.query.expose @currNs, 'says', (phrase) -> @where('greeting').equals(phrase)
          queries: (query) ->
            return [ query(@currNs).says('hello') ]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', greeting: 'hello'}
          mutate: (model) ->
            model.set "#{@currNs}.1.greeting", 'hello'

        it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', greeting: 'foo'}]
          withStore: (store) ->
            store.query.expose @currNs, 'says', (phrase) -> @where('greeting').equals(phrase)
          queries: (query) ->
            return [query(@currNs).says('foo')]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', greeting: 'foo'}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          mutate: (model) ->
            model.set "#{@currNs}.1.greeting", 'hello'

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', greeting: 'foo', age: 21}]
          withStore: (store) ->
            store.query.expose @currNs, 'says', (phrase) -> @where('greeting').equals(phrase)
            store.query.expose @currNs, 'yearsOld', (age) -> @where('age').equals(age)
          queries: (query) ->
            return [
              query(@currNs).says('foo')
              query(@currNs).yearsOld(21)
            ]
          listenForMutation: (model, onMutation) ->
            # This should never get called. Keep it here to detect if we call > 1
            # TODO Rm line below
            model.on 'rmDoc', -> throw new Error
            model.on 'rmDoc', spy = sinon.spy()
            expect(spy).to.have.callCount(0)

            model.on 'set', "#{@currNs}.1.greeting", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', greeting: 'foo', age: 21}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', greeting: 'hello', age: 21}
          mutate: (model) ->
            model.set "#{@currNs}.1.greeting", 'hello'

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', age: 27}]
          withStore: (store) ->
            store.query.expose @currNs, 'yearsOld', (age) -> @where('age').equals(age)
          queries: (query) ->
            return [
              query(@currNs).yearsOld(27)
              query(@currNs).yearsOld(28)
            ]
          listenForMutation: (model, onMutation) ->
            # This should never get called. Keep it here to detect if we call > 1
            model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
            model.on 'set', "#{@currNs}.1.age", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 27}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 28}
          mutate: (model) ->
            model.set "#{@currNs}.1.age", 28

        describe 'remotely', ->
          describe 'that causes an addition to the query set', ->
            describe 'and newly subscribed to the data', ->
              it 'should update the relevant query results alias', (done) ->
                {store, currNs} = this
                docOne = id: '1', age: 20
                docTwo = id: '2', age: 19
                store.query.expose currNs, 'xYearsOrOlder', (age) ->
                  @where('age').gte(age).sort('age', 'asc')
                store.query.expose currNs, 'youngestToOldest', ->
                  @sort('age', 'asc')
                mockFullSetup store, done, plugins, (modelA, modelB, done) ->
                  store.set "#{currNs}.1", docOne, null, ->
                    store.set "#{currNs}.2", docTwo, null, ->
                      modelA.subscribe modelA.query(currNs).xYearsOrOlder(20).youngestToOldest(), (err, results) ->
                        expect(results.get()).to.eql [docOne]
                        results.on 'insert', ->
                          expect(results.get()).to.eql [docOne, {id: '2', age: 21}]
                          done()

                        modelB.set "#{currNs}.2.age", 21
            describe 'and prior subscribed to the changed data', ->
              it 'should update the relevant query results alias', (done) ->
                {store, currNs} = this
                docOne = id: '1', age: 20
                docTwo = id: '2', age: 19
                store.query.expose currNs, 'xYearsOrOlder', (age) -> @where('age').gte(age)
                store.query.expose currNs, 'youngestToOldest', -> @sort('age', 'asc')
                mockFullSetup store, done, plugins, (modelA, modelB, done) ->
                  store.set "#{currNs}.1", docOne, null, ->
                    store.set "#{currNs}.2", docTwo, null, ->
                      modelA.subscribe "#{currNs}.2", modelA.query(currNs).xYearsOrOlder(20).youngestToOldest(), (err, docTwoScope, results) ->
                        expect(results.get()).to.eql [docOne]
                        results.on 'insert', ->
                          expect(results.get()).to.eql [docOne, {id: '2', age: 21}]
                          done()

                        modelB.set "#{currNs}.2.age", 21

          describe 'that causes a deletion from the query set', ->
            it 'should update the relevant query results alias', (done) ->
              {store, currNs} = this
              docOne = id: '1', age: 20
              docTwo = id: '2', age: 21
              store.query.expose currNs, 'xYearsOrOlder', (age) -> @where('age').gte(age)
              store.query.expose currNs, 'youngestToOldest', -> @sort('age', 'asc')
              mockFullSetup store, done, plugins, (modelA, modelB, done) ->
                store.set "#{currNs}.1", docOne, null, ->
                  store.set "#{currNs}.2", docTwo, null, ->
                    modelA.subscribe modelA.query(currNs).xYearsOrOlder(20).youngestToOldest(), (err, results) ->
                      expect(results.get()).to.eql [docOne, docTwo]
                      results.on 'remove', ->
                        expect(results.get()).to.eql [docOne]
                        done()

                      modelB.set "#{currNs}.2.age", 19

        describe 'locally', ->
          describe 'that causes an addition to the query set', ->
            it 'should update the relevant query results alias', (done) ->
              {store, currNs} = this
              docOne = id: '1', age: 20
              docTwo = id: '2', age: 19
              store.query.expose currNs, 'xYearsOrOlder', (age) -> @where('age').gte(age)
              store.query.expose currNs, 'youngestToOldest', -> @sort('age', 'asc')
              mockFullSetup store, done, plugins, (modelA, done) ->
                store.set "#{currNs}.1", docOne, null, ->
                  store.set "#{currNs}.2", docTwo, null, ->
                    modelA.subscribe modelA.query(currNs).xYearsOrOlder(20).youngestToOldest(), (err, results) ->
                      expect(results.get()).to.eql [docOne]
                      results.on 'insert', ->
                        expect(results.get()).to.specEql [docOne, {id: '2', age: 21}]
                        done()

                      modelA.set "#{currNs}.2.age", 21

          describe 'that causes a deletion from the query set', ->
            it 'should update the relevant query results alias', (done) ->
              {store, currNs} = this
              docOne = id: '1', age: 20
              docTwo = id: '2', age: 21
              store.query.expose currNs, 'xYearsOrOlder', (age) -> @where('age').gte(20)
              store.query.expose currNs, 'youngestToOldest', -> @sort('age', 'asc')
              mockFullSetup store, done, plugins, (modelA, done) ->
                store.set "#{currNs}.1", docOne, null, ->
                  store.set "#{currNs}.2", docTwo, null, ->
                    modelA.subscribe modelA.query(currNs).xYearsOrOlder(20).youngestToOldest(), (err, results) ->
                      expect(results.get()).to.eql [docOne, docTwo]
                      results.on 'remove', ->
                        expect(results.get()).to.eql [docOne]
                        done()

                      modelA.set "#{currNs}.2.age", 19

      describe 'for gt queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', age: 27}]
          withStore: (store) ->
            store.query.expose @currNs, 'olderThan', (age) -> @where('age').gt(age)
          queries: (query) -> [query(@currNs).olderThan(27)]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 28}
          mutate: (model) ->
            model.set "#{@currNs}.1.age", 28

        it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', age: 28}]
          withStore: (store) ->
            store.query.expose @currNs, 'olderThan', (age) -> @where('age').gt(age)
          queries: (query) -> [query(@currNs).olderThan(27)]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 28}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          mutate: (model) ->
            model.set "#{@currNs}.1.age", 27

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', age: 23}]
          withStore: (store) ->
            store.query.expose @currNs, 'olderThan', (age) -> @where('age').gt(age)
          queries: (query) ->
            return [
              query(@currNs).olderThan(21)
              query(@currNs).olderThan(22)
            ]
          listenForMutation: (model, onMutation, finish) ->
            model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
            model.on 'set', "#{@currNs}.1.age", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 23}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 22}
          mutate: (model) ->
            model.set "#{@currNs}.1.age", 22

    # TODO gte, lt, lte queries testing

      describe 'for within queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', age: 27}]
          withStore: (store) ->
            store.query.expose @currNs, 'eitherAged', (ages) -> @where('age').within(ages)
          queries: (query) -> [query(@currNs).eitherAged([28, 29, 30])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 30}
          mutate: (model) ->
            model.set "#{@currNs}.1.age", 30

        it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', age: 27}]
          withStore: (store) ->
            store.query.expose @currNs, 'eitherAged', (ages) -> @where('age').within(ages)
          queries: (query) -> [query(@currNs).eitherAged([27, 28])]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 27}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          mutate: (model) ->
            model.set "#{@currNs}.1.age", 29

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation'+
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', age: 27}]
          withStore: (store) ->
            store.query.expose @currNs, 'eitherAged', (ages) -> @where('age').within(ages)
          queries: (query) ->
            return [
              query(@currNs).eitherAged([27, 28])
              query(@currNs).eitherAged([27, 30])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'set', "#{@currNs}.1.age", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 27}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 30}
          mutate: (model) ->
            model.set "#{@currNs}.1.age", 30

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', age: 27}]
          withStore: (store) ->
            store.query.expose @currNs, 'eitherAged', (ages) -> @where('age').within(ages)
          queries: (query) ->
            return [
              query(@currNs).eitherAged([27, 29])
              query(@currNs).eitherAged([28, 29])
            ]
          listenForMutation: (model, onMutation) ->
            # This should never get called. Keep it here to detect if we call > 1
            model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
            model.on 'set', "#{@currNs}.1.age", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 27}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 28}
          mutate: (model) ->
            model.set "#{@currNs}.1.age", 28

    describe 'del <namespace>.<id>', ->
      it 'should remove the modified doc from any models subscribed to a query matching the doc pre-del', test
        initialDoc: -> ["#{@currNs}.1", {id: '1', age: 28}]
        withStore: (store) ->
          store.query.expose @currNs, 'yearsOld', (age) -> @where('age').equals(age)
        queries: (query) -> [query(@currNs).yearsOld(28)]
        listenForMutation: (model, onMutation) ->
          model.on 'rmDoc', onMutation
        preCondition: (model) ->
          expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 28}
        postCondition: (model) ->
          expect(model.get "#{@currNs}.1").to.equal undefined
        mutate: (model) ->
          model.del "#{@currNs}.1"

    describe 'del <namespace>.<id>.*', ->
      it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
        initialDoc: -> ["#{@currNs}.1", {id: '1', name: 'Brian'}]
        withStore: (store) ->
          store.query.expose @currNs, 'notNamed', (name) -> @where('name').notEquals(name)
        queries: (query) -> [query(@currNs).notNamed('Brian')]
        listenForMutation: (model, onMutation) ->
          model.on 'addDoc', onMutation
        preCondition: (model) ->
          expect(model.get "#{@currNs}.1").to.equal undefined
        postCondition: (model) ->
          model.get "#{@currNs}.1", {id: '1'}
        mutate: (model) ->
          model.del "#{@currNs}.1.name"

      it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
        initialDoc: -> ["#{@currNs}.1", {id: '1', name: 'Brian'}]
        withStore: (store) ->
          store.query.expose @currNs, 'named', (name) -> @where('name').equals(name)
        queries: (query) -> [query(@currNs).named('Brian')]
        listenForMutation: (model, onMutation) ->
          model.on 'rmDoc', onMutation
        preCondition: (model) ->
          expect(model.get "#{@currNs}.1").to.eql {id: '1', name: 'Brian'}
        postCondition: (model) ->
          expect(model.get "#{@currNs}.1").to.equal undefined
        mutate: (model) ->
          model.del "#{@currNs}.1.name"

      it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation' +
         'and (2) a query matching the doc both pre- and post-mutation', test
        initialDoc: -> ["#{@currNs}.1", {id: '1', name: 'Brian', age: 27}]
        withStore: (store) ->
          store.query.expose @currNs, 'named', (name) -> @where('name').equals(name)
          store.query.expose @currNs, 'yearsOld', (age) -> @where('age').equals(age)
        queries: (query) ->
          return [
            query(@currNs).named('Brian')
            query(@currNs).yearsOld(27)
          ]
        listenForMutation: (model, onMutation) ->
          model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
          model.on 'del', "#{@currNs}.1.age", onMutation
        preCondition: (model) ->
          expect(model.get "#{@currNs}.1").to.eql {id: '1', name: 'Brian', age: 27}
        postCondition: (model) ->
          expect(model.get "#{@currNs}.1").to.eql {id: '1', name: 'Brian'}
        mutate: (model) ->
          model.del "#{@currNs}.1.age"

      it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
         ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
        initialDoc: -> ["#{@currNs}.1", {id: '1', name: 'Brian'}]
        withStore: (store) ->
          store.query.expose @currNs, 'named', (name) -> @where('name').equals(name)
          store.query.expose @currNs, 'notNamed', (name) -> @where('name').notEquals(name)
        queries: (query) ->
          return [
            query(@currNs).named('Brian')
            query(@currNs).notNamed('Brian')
          ]
        listenForMutation: (model, onMutation) ->
          model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
          model.on 'addDoc', -> throw new Error 'Should not addDoc'
          model.on 'del', "#{@currNs}.1.name", onMutation
        preCondition: (model) ->
          expect(model.get "#{@currNs}.1").to.eql {id: '1', name: 'Brian'}
        postCondition: (model) ->
          expect(model.get "#{@currNs}.1").to.eql {id: '1'}
        mutate: (model) ->
          model.del "#{@currNs}.1.name"

    describe 'push', ->
      describe 'for contains queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['hi', 'ho']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) -> [query(@currNs).taggedWith(['hi', 'there'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['hi', 'ho', 'there']}
          mutate: (model) ->
            model.push "#{@currNs}.1.tags", 'there'

        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation (where the push occurs on undefined)', test
          initialDoc: -> ["#{@currNs}.1", {id: '1'}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) -> [query(@currNs).taggedWith(['hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['hi']}
          mutate: (model) ->
            model.push "#{@currNs}.1.tags", 'hi'

        it 'should keep the modified doc for any models subscribed to a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['hi', 'there']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) -> [query(@currNs).taggedWith(['there', 'hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'push', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['hi', 'there']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['hi', 'there', 'yo']}
          mutate: (model) ->
            model.push "#{@currNs}.1.tags", 'yo'

        describe 'that causes an addition to the query set', ->
          it 'should update the relevant query results alias', (done) ->
            {store, currNs} = this
            docOne = id: '1', tags: ['a', 'b', 'c']
            docTwo = id: '2', tags: ['c', 'd']
            store.query.expose currNs, 'taggedWithAndIdSorted', (tags) ->
              @where('tags').contains(['b', 'c']).sort('id', 'asc')
            mockFullSetup store, done, plugins, (modelA, modelB, done) ->
              store.set "#{currNs}.1", docOne, null, ->
                store.set "#{currNs}.2", docTwo, null, ->
                  modelA.subscribe modelA.query(currNs).taggedWithAndIdSorted(['b', 'c']), (err, results) ->
                    expect(results.get()).to.eql [docOne]
                    results.on 'insert', ->
                      expect(results.get()).to.eql [docOne, {id: '2', tags: ['b', 'c', 'd']}]
                      done()
                    modelB.unshift "#{currNs}.2.tags", 'b'


      describe 'for equals queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['red']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedExactlyWith', (tags) -> @where('tags').equals(tags)
          queries: (query) -> [query(@currNs).taggedExactlyWith(['red', 'alert'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['red', 'alert']}
          mutate: (model) ->
            model.push "#{@currNs}.1.tags", 'alert'

        it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['red']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedExactlyWith', (tags) -> @where('tags').equals(tags)
          queries: (query) -> [query(@currNs).taggedExactlyWith(['red'])]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['red']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          mutate: (model) ->
            model.push "#{@currNs}.1.tags", 'alert'

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['command']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedExactlyWith', (tags) -> @where('tags').equals(tags)
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) ->
            return [
              query(@currNs).taggedExactlyWith(['command', 'and', 'conquer'])
              query(@currNs).taggedWith(['command'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'push', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['command']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['command', 'and', 'conquer']}
          mutate: (model) ->
            model.push "#{@currNs}.1.tags", 'and', 'conquer'

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: [{a: 1, b: 2}]}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedExactlyWith', (tags) -> @where('tags').equals(tags)
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) ->
            return [
              query(@currNs).taggedExactlyWith [{a: 1, b: 2}]
              query(@currNs).taggedWith [{c: 10, d: 11}, {a: 1, b: 2}]
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'push', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: [{a: 1, b: 2}]}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: [{a: 1, b: 2}, {c: 10, d: 11}]}
          mutate: (model) ->
            model.push "#{@currNs}.1.tags", {c: 10, d: 11}

    describe 'unshift', ->
      describe 'for contains queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['ho', 'there']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) -> [query(@currNs).taggedWith(['hi', 'ho'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['hi', 'ho', 'there']}
          mutate: (model) ->
            model.unshift "#{@currNs}.1.tags", 'hi'

        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation (where the push occurs on undefined)', test
          initialDoc: -> ["#{@currNs}.1", {id: '1'}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) -> [query(@currNs).taggedWith(['hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['hi']}
          mutate: (model) ->
            model.unshift "#{@currNs}.1.tags", 'hi'

        it 'should keep the modified doc for any models subscribed to a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['hi', 'there']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) -> [query(@currNs).taggedWith(['there', 'hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'unshift', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['hi', 'there']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['yo', 'hi', 'there']}
          mutate: (model) ->
            model.unshift "#{@currNs}.1.tags", 'yo'

      describe 'for equals queries', ->

    describe 'insert', ->
      describe 'for contains queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['ho', 'there']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) -> [query(@currNs).taggedWith(['hi', 'ho'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['ho', 'hi', 'there']}
          mutate: (model) ->
            model.insert "#{@currNs}.1.tags", 1, 'hi'

        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation (where the push occurs on undefined)', test
          initialDoc: -> ["#{@currNs}.1", {id: '1'}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) -> [query(@currNs).taggedWith(['hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['hi']}
          mutate: (model) ->
            model.insert "#{@currNs}.1.tags", 0, 'hi'

        it 'should keep the modified doc for any models subscribed to a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['hi', 'there']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) -> [query(@currNs).taggedWith(['there', 'hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'insert', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['hi', 'there']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['hi', 'yo', 'there']}
          mutate: (model) ->
            model.insert "#{@currNs}.1.tags", 1, 'yo'

      describe 'for equals queries', ->

    describe 'pop', ->
      describe 'for contains queries', ->
        it 'should remove the modified doc from any models subscribed to a query matching the doc preo-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['red', 'orange']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) -> [query(@currNs).taggedWith(['red', 'orange'])]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['red', 'orange']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          mutate: (model) ->
            model.pop "#{@currNs}.1.tags"

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation' +
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['venti', 'grande']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) ->
            return [
              query(@currNs).taggedWith(['venti', 'grande'])
              query(@currNs).taggedWith(['venti'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'pop', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['venti', 'grande']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['venti']}
          mutate: (model) ->
            model.pop "#{@currNs}.1.tags"

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['walter', 'white']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
            store.query.expose @currNs, 'taggedExactlyWith', (tags) -> @where('tags').equals(tags)
          queries: (query) ->
            return [
              query(@currNs).taggedWith(['walter', 'white'])
              query(@currNs).taggedExactlyWith(['walter'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'pop', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['walter', 'white']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['walter']}
          mutate: (model) ->
            model.pop "#{@currNs}.1.tags"

      describe 'for equals queries', ->

    describe 'shift', ->
      describe 'for contains queries', ->
        it 'should remove the modified doc from any models subscribed to a query matching the doc preo-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['red', 'orange']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) -> [query(@currNs).taggedWith(['red', 'orange'])]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['red', 'orange']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          mutate: (model) ->
            model.shift "#{@currNs}.1.tags"

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation' +
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['venti', 'grande']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) ->
            return [
              query(@currNs).taggedWith(['venti', 'grande'])
              query(@currNs).taggedWith(['grande'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'shift', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['venti', 'grande']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['grande']}
          mutate: (model) ->
            model.shift "#{@currNs}.1.tags"

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['walter', 'white']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
            store.query.expose @currNs, 'taggedExactlyWith', (tags) -> @where('tags').equals(tags)
          queries: (query) ->
            return [
              query(@currNs).taggedWith(['walter', 'white'])
              query(@currNs).taggedExactlyWith(['white'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'shift', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['walter', 'white']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['white']}
          mutate: (model) ->
            model.shift "#{@currNs}.1.tags"

      describe 'for equals queries', ->

    describe 'remove', ->
      describe 'for contains queries', ->
        it 'should remove the modified doc from any models subscribed to a query matching the doc preo-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['red', 'orange', 'yellow']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) -> [query(@currNs).taggedWith(['red', 'orange'])]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['red', 'orange', 'yellow']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          mutate: (model) ->
            model.remove "#{@currNs}.1.tags", 1, 1

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation' +
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['piquito', 'venti', 'grande']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
          queries: (query) ->
            return [
              query(@currNs).taggedWith(['venti', 'grande'])
              query(@currNs).taggedWith(['grande'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'remove', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['piquito', 'venti', 'grande']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['piquito', 'grande']}
          mutate: (model) ->
            model.remove "#{@currNs}.1.tags", 1, 1

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['walter', 'jesse', 'white']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
            store.query.expose @currNs, 'taggedExactlyWith', (tags) -> @where('tags').equals(tags)
          queries: (query) ->
            return [
              query(@currNs).taggedWith(['walter', 'white'])
              query(@currNs).taggedExactlyWith(['white', 'white'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'remove', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['walter', 'jesse', 'white']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['walter', 'white']}
          mutate: (model) ->
            model.remove "#{@currNs}.1.tags", 1, 1

    describe 'move', ->
      describe 'for equals queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['alert', 'red']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedExactlyWith', (tags) -> @where('tags').equals(tags)
          queries: (query) -> [query(@currNs).taggedExactlyWith(['red', 'alert'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['red', 'alert']}
          mutate: (model) ->
            model.move "#{@currNs}.1.tags", 0, 1

        it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['red', 'alert']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedExactlyWith', (tags) -> @where('tags').equals(tags)
          queries: (query) -> [query(@currNs).taggedExactlyWith(['red', 'alert'])]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['red', 'alert']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.equal undefined
          mutate: (model) ->
            model.push "#{@currNs}.1.tags", 1, 0

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['command', 'and', 'conquer']}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedWith', (tags) -> @where('tags').contains(tags)
            store.query.expose @currNs, 'taggedExactlyWith', (tags) -> @where('tags').equals(tags)
          queries: (query) ->
            return [
              query(@currNs).taggedExactlyWith(['command', 'and', 'conquer'])
              query(@currNs).taggedWith(['conquer', 'command', 'and'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'move', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['command', 'and', 'conquer']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['conquer', 'command', 'and']}
          mutate: (model) ->
            model.move "#{@currNs}.1.tags", 2, 0

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: [{a: 1}, {b: 2}, {c: 3}]}]
          withStore: (store) ->
            store.query.expose @currNs, 'taggedExactlyWith', (tags) -> @where('tags').equals(tags)
          queries: (query) ->
            return [
              query(@currNs).taggedExactlyWith [{a: 1}, {b: 2}, {c: 3}]
              query(@currNs).taggedExactlyWith [{a: 1}, {c: 3}, {b: 2}]
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'move', "#{@currNs}.1.tags", onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: [{a: 1}, {b: 2}, {c: 3}]}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: [{a: 1}, {c: 3}, {b: 2}]}
          mutate: (model) ->
            model.move "#{@currNs}.1.tags", 2, 1

    describe 'only queries', ->
      # TODO
      it 'should not propagate properties not in `only`'#, test
  #              # TODO Note this is a stronger requirement than "should not
  #              # assign properties" because we want to hide data for security
  #              # reasons
  #              initialDoc: -> ["#{@currNs}.1", {id: '1', name: 'brian', age: 26, city: 'sf'}]
  #              queries: (query) -> [query(@currNs).where('name').equals('bri').only('name', 'city')]
  #              listenForMutation: (model, onMutation) ->
  #                model.on 'addDoc', onMutation
  #              preCondition: (model) ->
  #                expect(model.get "#{@currNs}.1").to.equal undefined
  #              postCondition: (model) ->
  #                expect(model.get "#{@currNs}.1").to.eql {id: '1', name: 'bri', city: 'sf'}
  #              mutate: (model) ->
  #                model.set "#{@currNs}.1.name", 'bri'

      # TODO
      it 'should not propagate transactions that involve paths outside of the `only` query param'
        # TODO Note this is a stronger requirement than "should not
        # assign properties" because we want to hide data for security
        # reasons

      it 'should not propagate transactions that involve paths in the `except` query param'

      it 'should proapgate transactions that involve a query-matching doc if the transaction involves a path in the `only` query param'

      it 'should propagate transactions that involve a query-matching doc if the transaction involves a path not in the `exclude` query param'
