{expect} = require '../util'
{finishAfter} = require '../../lib/util/async'
{mockFullSetup} = require '../util/model'

module.exports = (plugins) ->
  describe 'subscribe', ->
    describe 'set <namespace>.<id>', ->
      userLeo  = id: '1', name: 'leo'
      userBill = id: '2', name: 'bill'
      userSue  = id: '3', name: 'sue'

      it 'should publish the txn *only* to relevant live `equals` queries', (done) ->
        {store, currNs} = this
        mockFullSetup store, done, plugins, (modelLeo, modelBill, done) ->
          finish = finishAfter 2, ->
            modelSue = store.createModel()
            modelSue.set "#{currNs}.1", userLeo
            modelSue.set "#{currNs}.2", userBill
            modelSue.set "#{currNs}.3", userSue
            done()

          queryLeo = modelLeo.query(currNs).where('name').equals('leo')
          modelLeo.subscribe queryLeo, ->
            modelLeo.on 'set', "#{currNs}.*", (id, user) ->
              expect(id).to.equal '1'
              expect(user).to.eql userLeo
            finish()

          queryBill = modelBill.query(currNs).where('name').equals('bill')
          modelBill.subscribe queryBill, ->
            modelBill.on 'set', "#{currNs}.*", (id, user) ->
              expect(id).to.equal '2'
              expect(user).to.eql userBill
            finish()

    storeId = 1
    test = ({initialDoc, queries, preCondition, postCondition, mutate, listenForMutation}) ->
      return (done) ->
        {store} = testContext = this
        mockFullSetup store, done, plugins, (modelA, modelB, done) ->
          [key, doc] = initialDoc.call testContext
          store.set key, doc, null, ->
            listenForMutation.call testContext, modelA, ->
              postCondition.call testContext, modelA
              done()
            modelA.subscribe queries.call(testContext, modelA.query)..., ->
              preCondition.call testContext, modelA
              mutate.call testContext, modelB

    describe 'set <namespace>.<id>.*', ->
      describe 'for equals queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', greeting: 'foo'}]
          queries: (query) ->
            return [ query(@currNs).where('greeting').equals('hello') ]
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
          queries: (query) ->
            return [query(@currNs).where('greeting').equals('foo')]
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
          queries: (query) ->
            return [
              query(@currNs).where('greeting').equals('foo')
              query(@currNs).where('age').equals(21)
            ]
          listenForMutation: (model, onMutation) ->
            # This should never get called. Keep it here to detect if we call > 1
            model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
            model.on 'set', "#{@currNs}.1.greeting", (value) ->
              expect(value).to.equal 'hello'
              onMutation()
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', greeting: 'foo', age: 21}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', greeting: 'hello', age: 21}
          mutate: (model) ->
            model.set "#{@currNs}.1.greeting", 'hello'

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', age: 27}]
          queries: (query) ->
            return [
              query(@currNs).where('age').equals(27)
              query(@currNs).where('age').equals(28)
            ]
          listenForMutation: (model, onMutation) ->
            # This should never get called. Keep it here to detect if we call > 1
            model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
            model.on 'set', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 27}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 28}
          mutate: (model) ->
            model.set "#{@currNs}.1.age", 28

      describe 'for gt queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', age: 27}]
          queries: (query) -> [query(@currNs).where('age').gt(27)]
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
          queries: (query) -> [query(@currNs).where('age').gt(27)]
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
          queries: (query) ->
            return [
              query(@currNs).where('age').gt(21)
              query(@currNs).where('age').gt(22)
            ]
          listenForMutation: (model, onMutation, finish) ->
            model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
            model.on 'set', onMutation
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
          queries: (query) -> [query(@currNs).where('age').within([28, 29, 30])]
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
          queries: (query) -> [query(@currNs).where('age').within([27, 28])]
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
          queries: (query) ->
            return [
              query(@currNs).where('age').within([27, 28])
              query(@currNs).where('age').within([27, 30])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'set', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 27}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 30}
          mutate: (model) ->
            model.set "#{@currNs}.1.age", 30

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', age: 27}]
          queries: (query) ->
            return [
              query(@currNs).where('age').within([27, 29])
              query(@currNs).where('age').within([28, 29])
            ]
          listenForMutation: (model, onMutation) ->
            # This should never get called. Keep it here to detect if we call > 1
            model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
            model.on 'set', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 27}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', age: 28}
          mutate: (model) ->
            model.set "#{@currNs}.1.age", 28

    describe 'del <namespace>.<id>', ->
      it 'should remove the modified doc from any models subscribed to a query matching the doc pre-del', test
        initialDoc: -> ["#{@currNs}.1", {id: '1', age: 28}]
        queries: (query) -> [query(@currNs).where('age').equals(28)]
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
        queries: (query) -> [query(@currNs).where('name').notEquals('Brian')]
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
        queries: (query) -> [query(@currNs).where('name').equals('Brian')]
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
        queries: (query) ->
          return [
            query(@currNs).where('name').equals('Brian')
            query(@currNs).where('age').equals(27)
          ]
        listenForMutation: (model, onMutation) ->
          model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
          model.on 'del', onMutation
        preCondition: (model) ->
          expect(model.get "#{@currNs}.1").to.eql {id: '1', name: 'Brian', age: 27}
        postCondition: (model) ->
          expect(model.get "#{@currNs}.1").to.eql {id: '1', name: 'Brian'}
        mutate: (model) ->
          model.del "#{@currNs}.1.age"

      it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
         ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
        initialDoc: -> ["#{@currNs}.1", {id: '1', name: 'Brian'}]
        queries: (query) ->
          return [
            query(@currNs).where('name').equals('Brian')
            query(@currNs).where('name').notEquals('Brian')
          ]
        listenForMutation: (model, onMutation) ->
          model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
          model.on 'addDoc', -> throw new Error 'Should not addDoc'
          model.on 'del', onMutation
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
          queries: (query) -> [query(@currNs).where('tags').contains(['hi', 'there'])]
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
          queries: (query) -> [query(@currNs).where('tags').contains(['hi'])]
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
          queries: (query) -> [query(@currNs).where('tags').contains(['there', 'hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'push', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['hi', 'there']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['hi', 'there', 'yo']}
          mutate: (model) ->
            model.push "#{@currNs}.1.tags", 'yo'

      describe 'for equals queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['red']}]
          queries: (query) -> [query(@currNs).where('tags').equals(['red', 'alert'])]
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
          queries: (query) -> [query(@currNs).where('tags').equals(['red'])]
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
          queries: (query) ->
            return [
              query(@currNs).where('tags').equals(['command', 'and', 'conquer'])
              query(@currNs).where('tags').contains(['command'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'push', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['command']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['command', 'and', 'conquer']}
          mutate: (model) ->
            model.push "#{@currNs}.1.tags", 'and', 'conquer'

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: [{a: 1, b: 2}]}]
          queries: (query) ->
            return [
              query(@currNs).where('tags').equals [{a: 1, b: 2}]
              query(@currNs).where('tags').contains [{c: 10, d: 11}, {a: 1, b: 2}]
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'push', onMutation
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
          queries: (query) -> [query(@currNs).where('tags').contains(['hi', 'ho'])]
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
          queries: (query) -> [query(@currNs).where('tags').contains(['hi'])]
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
          queries: (query) -> [query(@currNs).where('tags').contains(['there', 'hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'unshift', onMutation
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
          queries: (query) -> [query(@currNs).where('tags').contains(['hi', 'ho'])]
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
          queries: (query) -> [query(@currNs).where('tags').contains(['hi'])]
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
          queries: (query) -> [query(@currNs).where('tags').contains(['there', 'hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'insert', onMutation
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
          queries: (query) -> [query(@currNs).where('tags').contains(['red', 'orange'])]
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
          queries: (query) ->
            return [
              query(@currNs).where('tags').contains(['venti', 'grande'])
              query(@currNs).where('tags').contains(['venti'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'pop', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['venti', 'grande']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['venti']}
          mutate: (model) ->
            model.pop "#{@currNs}.1.tags"

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['walter', 'white']}]
          queries: (query) ->
            return [
              query(@currNs).where('tags').contains(['walter', 'white'])
              query(@currNs).where('tags').equals(['walter'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'pop', onMutation
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
          queries: (query) -> [query(@currNs).where('tags').contains(['red', 'orange'])]
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
          queries: (query) ->
            return [
              query(@currNs).where('tags').contains(['venti', 'grande'])
              query(@currNs).where('tags').contains(['grande'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'shift', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['venti', 'grande']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['grande']}
          mutate: (model) ->
            model.shift "#{@currNs}.1.tags"

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['walter', 'white']}]
          queries: (query) ->
            return [
              query(@currNs).where('tags').contains(['walter', 'white'])
              query(@currNs).where('tags').equals(['white'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'shift', onMutation
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
          queries: (query) -> [query(@currNs).where('tags').contains(['red', 'orange'])]
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
          queries: (query) ->
            return [
              query(@currNs).where('tags').contains(['venti', 'grande'])
              query(@currNs).where('tags').contains(['grande'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'remove', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['piquito', 'venti', 'grande']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['piquito', 'grande']}
          mutate: (model) ->
            model.remove "#{@currNs}.1.tags", 1, 1

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: ['walter', 'jesse', 'white']}]
          queries: (query) ->
            return [
              query(@currNs).where('tags').contains(['walter', 'white'])
              query(@currNs).where('tags').equals(['white', 'white'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'remove', onMutation
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
          queries: (query) -> [query(@currNs).where('tags').equals(['red', 'alert'])]
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
          queries: (query) -> [query(@currNs).where('tags').equals(['red', 'alert'])]
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
          queries: (query) ->
            return [
              query(@currNs).where('tags').equals(['command', 'and', 'conquer'])
              query(@currNs).where('tags').contains(['conquer', 'command', 'and'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'move', onMutation
          preCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['command', 'and', 'conquer']}
          postCondition: (model) ->
            expect(model.get "#{@currNs}.1").to.eql {id: '1', tags: ['conquer', 'command', 'and']}
          mutate: (model) ->
            model.move "#{@currNs}.1.tags", 2, 0

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{@currNs}.1", {id: '1', tags: [{a: 1}, {b: 2}, {c: 3}]}]
          queries: (query) ->
            return [
              query(@currNs).where('tags').equals [{a: 1}, {b: 2}, {c: 3}]
              query(@currNs).where('tags').equals [{a: 1}, {c: 3}, {b: 2}]
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'move', onMutation
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
