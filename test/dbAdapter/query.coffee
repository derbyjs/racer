{finishAfter, forEach} = require '../../src/util'
{expect} = require '../util'
{mockFullSetup} = require '../util/model'

module.exports = (getStore) ->
  currCollectionIndex = 0
  nsBase = 'users_'
  currNs = null
  store = null

  beforeEach ->
    store = getStore()
    currNs = nsBase + currCollectionIndex++

  afterEach (done) ->
    store._db.version = 0
    store.flushJournal done

  after (done) ->
    store.flush ->
      store.disconnect()
      done()

  describe 'subscribe fetches', ->
    users = [
      { id: '0', name: 'brian', age: 25, workdays: ['mon', 'tue', 'wed'] }
      { id: '1', name: 'nate' , age: 26, workdays: ['mon', 'wed', 'fri'] }
      { id: '2', name: 'x'    , age: 27, workdays: ['mon', 'thu', 'fri'] }
    ]

    beforeEach (done) ->
      forEach users, (user, callback) ->
        store.set "#{currNs}.#{user.id}", user, null, callback
      , done

    it 'should work for one parameter `equals` queries', (done) ->
      model = store.createModel()
      query = model.query(currNs).where('name').equals('brian')
      model.subscribe query, ->
        expect(model.get "#{currNs}.0").to.eql users[0]
        expect(model.get "#{currNs}.1").to.equal undefined
        expect(model.get "#{currNs}.2").to.equal undefined
        done()

    it 'should work for one parameter `gt` queries', (done) ->
      model = store.createModel()
      query = model.query(currNs).where('age').gt(25)
      model.subscribe query, ->
        expect(model.get "#{currNs}.0").to.equal undefined
        for i in [1, 2]
          expect(model.get currNs + '.' + i).to.eql users[i]
        done()

    it 'should work for one parameter `gte` queries', (done) ->
      model = store.createModel()
      query = model.query(currNs).where('age').gte(26)
      model.subscribe query, ->
        expect(model.get "#{currNs}.0").to.equal undefined
        for i in [1, 2]
          expect(model.get currNs + '.' + i).to.eql users[i]
        done()

    it 'should work for one parameter `lt` queries', (done) ->
      model = store.createModel()
      query = model.query(currNs).where('age').lt(27)
      model.subscribe query, ->
        for i in [0, 1]
          expect(model.get currNs + '.' + i).to.eql users[i]
        expect(model.get "#{currNs}.2").to.equal undefined
        done()

    it 'should work for one parameter `lte` queries', (done) ->
      model = store.createModel()
      query = model.query(currNs).where('age').lte(26)
      model.subscribe query, ->
        for i in [0, 1]
          expect(model.get currNs + '.' + i).to.eql users[i]
        expect(model.get "#{currNs}.2").to.equal undefined
        done()

    it 'should work for one parameter `within` queries', (done) ->
      model = store.createModel()
      query = model.query(currNs).where('name').within(['brian', 'x'])
      model.subscribe query, ->
        for i in [0, 2]
          expect(model.get currNs + '.' + i).to.eql users[i]
        expect(model.get "#{currNs}.1").to.equal undefined
        done()

    it 'should work for one parameter `contains` scalar queries', (done) ->
      model = store.createModel()
      query = model.query(currNs).where('workdays').contains(['mon', 'wed'])
      model.subscribe query, ->
        for i in [0, 1]
          expect(model.get currNs + '.' + i).to.eql users[i]
        expect(model.get "#{currNs}.2").to.equal undefined
        done()

    it 'should work for compound queries', (done) ->
      model = store.createModel()
      query = model.query(currNs).where('workdays').contains(['wed']).where('age').gt(25)
      model.subscribe query, ->
        for i in [0, 2]
          expect(model.get currNs + '.' + i).to.equal undefined
        expect(model.get "#{currNs}.1").to.eql users[1]
        done()

    it 'should only retrieve paths specified in `only`', (done) ->
      model = store.createModel()
      query = model.query(currNs).where('age').gt(20).only('name', 'age')
      model.subscribe query, ->
        for i in [0..2]
          expect(model.get currNs + '.' + i + '.id').to.equal users[i].id
          expect(model.get currNs + '.' + i + '.name').to.equal users[i].name
          expect(model.get currNs + '.' + i + '.age').to.equal users[i].age
          expect(model.get currNs + '.' + i + '.workdays').to.equal undefined
        done()

    it 'should exclude paths specified in `except`', (done) ->
      model = store.createModel()
      query = model.query(currNs).where('age').gt(20).except('name', 'workdays')
      model.subscribe query, ->
        for i in [0..2]
          expect(model.get currNs + '.' + i + '.id').to.equal users[i].id
          expect(model.get currNs + '.' + i + '.age').to.equal users[i].age
          expect(model.get currNs + '.' + i + '.name').to.equal undefined
          expect(model.get currNs + '.' + i + '.workdays').to.equal undefined
        done()

  describe 'receiving proper publishes', ->
    describe 'set <namespace>.<id>', ->
      userLeo  = id: '1', name: 'leo'
      userBill = id: '2', name: 'bill'
      userSue  = id: '3', name: 'sue'

      it 'should publish the txn *only* to relevant live `equals` queries',
        mockFullSetup getStore, {numBrowsers: 2}, (modelLeo, modelBill, done) ->
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

    test = ({initialDoc, queries, preCondition, postCondition, mutate, listenForMutation}) ->
      mockFullSetup getStore, {numBrowsers: 2}, (modelA, modelB, done) ->
        [key, doc] = initialDoc()
        store.set key, doc, null, ->
          listenForMutation modelA, ->
            postCondition modelA
            done()
          modelA.subscribe queries(modelA.query)..., ->
            preCondition modelA
            mutate modelB

    describe 'set <namespace>.<id>.*', ->
      describe 'for equals queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', greeting: 'foo'}]
          queries: (query) ->
            return [
              query(currNs).where('greeting').equals('hello')
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', greeting: 'hello'}
          mutate: (model) ->
            model.set "#{currNs}.1.greeting", 'hello'

        it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', greeting: 'foo'}]
          queries: (query) ->
            return [query(currNs).where('greeting').equals('foo')]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', greeting: 'foo'}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          mutate: (model) ->
            model.set "#{currNs}.1.greeting", 'hello'

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', greeting: 'foo', age: 21}]
          queries: (query) ->
            return [
              query(currNs).where('greeting').equals('foo')
              query(currNs).where('age').equals(21)
            ]
          listenForMutation: (model, onMutation) ->
            # This should never get called. Keep it here to detect if we call > 1
            model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
            model.on 'set', "#{currNs}.1.greeting", (value) ->
              expect(value).to.equal 'hello'
              onMutation()
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', greeting: 'foo', age: 21}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', greeting: 'hello', age: 21}
          mutate: (model) ->
            model.set "#{currNs}.1.greeting", 'hello'

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', age: 27}]
          queries: (query) ->
            return [
              query(currNs).where('age').equals(27)
              query(currNs).where('age').equals(28)
            ]
          listenForMutation: (model, onMutation) ->
            # This should never get called. Keep it here to detect if we call > 1
            model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
            model.on 'set', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', age: 27}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', age: 28}
          mutate: (model) ->
            model.set "#{currNs}.1.age", 28

      describe 'for gt queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', age: 27}]
          queries: (query) -> [query(currNs).where('age').gt(27)]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', age: 28}
          mutate: (model) ->
            model.set "#{currNs}.1.age", 28

        it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', age: 28}]
          queries: (query) -> [query(currNs).where('age').gt(27)]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', age: 28}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          mutate: (model) ->
            model.set "#{currNs}.1.age", 27

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', age: 23}]
          queries: (query) ->
            return [
              query(currNs).where('age').gt(21)
              query(currNs).where('age').gt(22)
            ]
          listenForMutation: (model, onMutation, finish) ->
            model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
            model.on 'set', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', age: 23}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', age: 22}
          mutate: (model) ->
            model.set "#{currNs}.1.age", 22

    # TODO gte, lt, lte queries testing

      describe 'for within queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', age: 27}]
          queries: (query) -> [query(currNs).where('age').within([28, 29, 30])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', age: 30}
          mutate: (model) ->
            model.set "#{currNs}.1.age", 30

        it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', age: 27}]
          queries: (query) -> [query(currNs).where('age').within([27, 28])]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', age: 27}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          mutate: (model) ->
            model.set "#{currNs}.1.age", 29

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation'+
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', age: 27}]
          queries: (query) ->
            return [
              query(currNs).where('age').within([27, 28])
              query(currNs).where('age').within([27, 30])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'set', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', age: 27}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', age: 30}
          mutate: (model) ->
            model.set "#{currNs}.1.age", 30

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', age: 27}]
          queries: (query) ->
            return [
              query(currNs).where('age').within([27, 29])
              query(currNs).where('age').within([28, 29])
            ]
          listenForMutation: (model, onMutation) ->
            # This should never get called. Keep it here to detect if we call > 1
            model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
            model.on 'set', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', age: 27}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', age: 28}
          mutate: (model) ->
            model.set "#{currNs}.1.age", 28

    describe 'del <namespace>.<id>', ->
      it 'should remove the modified doc from any models subscribed to a query matching the doc pre-del', test
        initialDoc: -> ["#{currNs}.1", {id: '1', age: 28}]
        queries: (query) -> [query(currNs).where('age').equals(28)]
        listenForMutation: (model, onMutation) ->
          model.on 'rmDoc', onMutation
        preCondition: (model) ->
          expect(model.get "#{currNs}.1").to.eql {id: '1', age: 28}
        postCondition: (model) ->
          expect(model.get "#{currNs}.1").to.equal undefined
        mutate: (model) ->
          model.del "#{currNs}.1"

    describe 'del <namespace>.<id>.*', ->
      it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
        initialDoc: -> ["#{currNs}.1", {id: '1', name: 'Brian'}]
        queries: (query) -> [query(currNs).where('name').notEquals('Brian')]
        listenForMutation: (model, onMutation) ->
          model.on 'addDoc', onMutation
        preCondition: (model) ->
          expect(model.get "#{currNs}.1").to.equal undefined
        postCondition: (model) ->
          model.get "#{currNs}.1", {id: '1'}
        mutate: (model) ->
          model.del "#{currNs}.1.name"

      it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
        initialDoc: -> ["#{currNs}.1", {id: '1', name: 'Brian'}]
        queries: (query) -> [query(currNs).where('name').equals('Brian')]
        listenForMutation: (model, onMutation) ->
          model.on 'rmDoc', onMutation
        preCondition: (model) ->
          expect(model.get "#{currNs}.1").to.eql {id: '1', name: 'Brian'}
        postCondition: (model) ->
          expect(model.get "#{currNs}.1").to.equal undefined
        mutate: (model) ->
          model.del "#{currNs}.1.name"

      it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation' + 
         'and (2) a query matching the doc both pre- and post-mutation', test
        initialDoc: -> ["#{currNs}.1", {id: '1', name: 'Brian', age: 27}]
        queries: (query) ->
          return [
            query(currNs).where('name').equals('Brian')
            query(currNs).where('age').equals(27)
          ]
        listenForMutation: (model, onMutation) ->
          model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
          model.on 'del', onMutation
        preCondition: (model) ->
          expect(model.get "#{currNs}.1").to.eql {id: '1', name: 'Brian', age: 27}
        postCondition: (model) ->
          expect(model.get "#{currNs}.1").to.eql {id: '1', name: 'Brian'}
        mutate: (model) ->
          model.del "#{currNs}.1.age"

      it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
         ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
        initialDoc: -> ["#{currNs}.1", {id: '1', name: 'Brian'}]
        queries: (query) ->
          return [
            query(currNs).where('name').equals('Brian')
            query(currNs).where('name').notEquals('Brian')
          ]
        listenForMutation: (model, onMutation) ->
          model.on 'rmDoc', -> throw new Error 'Should not rmDoc'
          model.on 'addDoc', -> throw new Error 'Should not addDoc'
          model.on 'del', onMutation
        preCondition: (model) ->
          expect(model.get "#{currNs}.1").to.eql {id: '1', name: 'Brian'}
        postCondition: (model) ->
          expect(model.get "#{currNs}.1").to.eql {id: '1'}
        mutate: (model) ->
          model.del "#{currNs}.1.name"

    describe 'incr', ->

    describe 'push', ->
      describe 'for contains queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['hi', 'ho']}]
          queries: (query) -> [query(currNs).where('tags').contains(['hi', 'there'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['hi', 'ho', 'there']}
          mutate: (model) ->
            model.push "#{currNs}.1.tags", 'there'

        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation (where the push occurs on undefined)', test
          initialDoc: -> ["#{currNs}.1", {id: '1'}]
          queries: (query) -> [query(currNs).where('tags').contains(['hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['hi']}
          mutate: (model) ->
            model.push "#{currNs}.1.tags", 'hi'

        it 'should keep the modified doc for any models subscribed to a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['hi', 'there']}]
          queries: (query) -> [query(currNs).where('tags').contains(['there', 'hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'push', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['hi', 'there']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['hi', 'there', 'yo']}
          mutate: (model) ->
            model.push "#{currNs}.1.tags", 'yo'

      describe 'for equals queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['red']}]
          queries: (query) -> [query(currNs).where('tags').equals(['red', 'alert'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['red', 'alert']}
          mutate: (model) ->
            model.push "#{currNs}.1.tags", 'alert'

        it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['red']}]
          queries: (query) -> [query(currNs).where('tags').equals(['red'])]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['red']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          mutate: (model) ->
            model.push "#{currNs}.1.tags", 'alert'

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['command']}]
          queries: (query) ->
            return [
              query(currNs).where('tags').equals(['command', 'and', 'conquer'])
              query(currNs).where('tags').contains(['command'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'push', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['command']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['command', 'and', 'conquer']}
          mutate: (model) ->
            model.push "#{currNs}.1.tags", 'and', 'conquer'

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: [{a: 1, b: 2}]}]
          queries: (query) ->
            return [
              query(currNs).where('tags').equals [{a: 1, b: 2}]
              query(currNs).where('tags').contains [{c: 10, d: 11}, {a: 1, b: 2}]
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'push', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: [{a: 1, b: 2}]}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: [{a: 1, b: 2}, {c: 10, d: 11}]}
          mutate: (model) ->
            model.push "#{currNs}.1.tags", {c: 10, d: 11}

    describe 'unshift', ->
      describe 'for contains queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['ho', 'there']}]
          queries: (query) -> [query(currNs).where('tags').contains(['hi', 'ho'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['hi', 'ho', 'there']}
          mutate: (model) ->
            model.unshift "#{currNs}.1.tags", 'hi'

        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation (where the push occurs on undefined)', test
          initialDoc: -> ["#{currNs}.1", {id: '1'}]
          queries: (query) -> [query(currNs).where('tags').contains(['hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['hi']}
          mutate: (model) ->
            model.unshift "#{currNs}.1.tags", 'hi'

        it 'should keep the modified doc for any models subscribed to a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['hi', 'there']}]
          queries: (query) -> [query(currNs).where('tags').contains(['there', 'hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'unshift', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['hi', 'there']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['yo', 'hi', 'there']}
          mutate: (model) ->
            model.unshift "#{currNs}.1.tags", 'yo'

      describe 'for equals queries', ->

    describe 'insert', ->
      describe 'for contains queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['ho', 'there']}]
          queries: (query) -> [query(currNs).where('tags').contains(['hi', 'ho'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['ho', 'hi', 'there']}
          mutate: (model) ->
            model.insert "#{currNs}.1.tags", 1, 'hi'

        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation (where the push occurs on undefined)', test
          initialDoc: -> ["#{currNs}.1", {id: '1'}]
          queries: (query) -> [query(currNs).where('tags').contains(['hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['hi']}
          mutate: (model) ->
            model.insert "#{currNs}.1.tags", 0, 'hi'

        it 'should keep the modified doc for any models subscribed to a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['hi', 'there']}]
          queries: (query) -> [query(currNs).where('tags').contains(['there', 'hi'])]
          listenForMutation: (model, onMutation) ->
            model.on 'insert', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['hi', 'there']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['hi', 'yo', 'there']}
          mutate: (model) ->
            model.insert "#{currNs}.1.tags", 1, 'yo'

      describe 'for equals queries', ->

    describe 'pop', ->
      describe 'for contains queries', ->
        it 'should remove the modified doc from any models subscribed to a query matching the doc preo-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['red', 'orange']}]
          queries: (query) -> [query(currNs).where('tags').contains(['red', 'orange'])]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['red', 'orange']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          mutate: (model) ->
            model.pop "#{currNs}.1.tags"

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation' +
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['venti', 'grande']}]
          queries: (query) ->
            return [
              query(currNs).where('tags').contains(['venti', 'grande'])
              query(currNs).where('tags').contains(['venti'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'pop', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['venti', 'grande']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['venti']}
          mutate: (model) ->
            model.pop "#{currNs}.1.tags"

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['walter', 'white']}]
          queries: (query) ->
            return [
              query(currNs).where('tags').contains(['walter', 'white'])
              query(currNs).where('tags').equals(['walter'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'pop', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['walter', 'white']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['walter']}
          mutate: (model) ->
            model.pop "#{currNs}.1.tags"

      describe 'for equals queries', ->

    describe 'shift', ->
      describe 'for contains queries', ->
        it 'should remove the modified doc from any models subscribed to a query matching the doc preo-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['red', 'orange']}]
          queries: (query) -> [query(currNs).where('tags').contains(['red', 'orange'])]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['red', 'orange']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          mutate: (model) ->
            model.shift "#{currNs}.1.tags"

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation' +
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['venti', 'grande']}]
          queries: (query) ->
            return [
              query(currNs).where('tags').contains(['venti', 'grande'])
              query(currNs).where('tags').contains(['grande'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'shift', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['venti', 'grande']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['grande']}
          mutate: (model) ->
            model.shift "#{currNs}.1.tags"

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['walter', 'white']}]
          queries: (query) ->
            return [
              query(currNs).where('tags').contains(['walter', 'white'])
              query(currNs).where('tags').equals(['white'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'shift', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['walter', 'white']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['white']}
          mutate: (model) ->
            model.shift "#{currNs}.1.tags"

      describe 'for equals queries', ->

    describe 'remove', ->
      describe 'for contains queries', ->
        it 'should remove the modified doc from any models subscribed to a query matching the doc preo-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['red', 'orange', 'yellow']}]
          queries: (query) -> [query(currNs).where('tags').contains(['red', 'orange'])]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['red', 'orange', 'yellow']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          mutate: (model) ->
            model.remove "#{currNs}.1.tags", 1, 1

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation' +
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['piquito', 'venti', 'grande']}]
          queries: (query) ->
            return [
              query(currNs).where('tags').contains(['venti', 'grande'])
              query(currNs).where('tags').contains(['grande'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'remove', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['piquito', 'venti', 'grande']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['piquito', 'grande']}
          mutate: (model) ->
            model.remove "#{currNs}.1.tags", 1, 1

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['walter', 'jesse', 'white']}]
          queries: (query) ->
            return [
              query(currNs).where('tags').contains(['walter', 'white'])
              query(currNs).where('tags').equals(['white', 'white'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'remove', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['walter', 'jesse', 'white']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['walter', 'white']}
          mutate: (model) ->
            model.remove "#{currNs}.1.tags", 1, 1

    describe 'move', ->
      describe 'for equals queries', ->
        it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['alert', 'red']}]
          queries: (query) -> [query(currNs).where('tags').equals(['red', 'alert'])]
          listenForMutation: (model, onMutation) ->
            model.on 'addDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['red', 'alert']}
          mutate: (model) ->
            model.move "#{currNs}.1.tags", 0, 1

        it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['red', 'alert']}]
          queries: (query) -> [query(currNs).where('tags').equals(['red', 'alert'])]
          listenForMutation: (model, onMutation) ->
            model.on 'rmDoc', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['red', 'alert']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.equal undefined
          mutate: (model) ->
            model.push "#{currNs}.1.tags", 1, 0

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           'and (2) a query matching the doc both pre- and post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: ['command', 'and', 'conquer']}]
          queries: (query) ->
            return [
              query(currNs).where('tags').equals(['command', 'and', 'conquer'])
              query(currNs).where('tags').contains(['conquer', 'command', 'and'])
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'move', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['command', 'and', 'conquer']}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: ['conquer', 'command', 'and']}
          mutate: (model) ->
            model.move "#{currNs}.1.tags", 2, 0

        it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
           ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
          initialDoc: -> ["#{currNs}.1", {id: '1', tags: [{a: 1}, {b: 2}, {c: 3}]}]
          queries: (query) ->
            return [
              query(currNs).where('tags').equals [{a: 1}, {b: 2}, {c: 3}]
              query(currNs).where('tags').equals [{a: 1}, {c: 3}, {b: 2}]
            ]
          listenForMutation: (model, onMutation) ->
            model.on 'move', onMutation
          preCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: [{a: 1}, {b: 2}, {c: 3}]}
          postCondition: (model) ->
            expect(model.get "#{currNs}.1").to.eql {id: '1', tags: [{a: 1}, {c: 3}, {b: 2}]}
          mutate: (model) ->
            model.move "#{currNs}.1.tags", 2, 1

    describe 'only queries', ->
      # TODO
      it 'should not propagate properties not in `only`'#, test
#              # TODO Note this is a stronger requirement than "should not
#              # assign properties" because we want to hide data for security
#              # reasons
#              initialDoc: -> ["#{currNs}.1", {id: '1', name: 'brian', age: 26, city: 'sf'}]
#              queries: (query) -> [query(currNs).where('name').equals('bri').only('name', 'city')]
#              listenForMutation: (model, onMutation) ->
#                model.on 'addDoc', onMutation
#              preCondition: (model) ->
#                expect(model.get "#{currNs}.1").to.equal undefined
#              postCondition: (model) ->
#                expect(model.get "#{currNs}.1").to.eql {id: '1', name: 'bri', city: 'sf'}
#              mutate: (model) ->
#                model.set "#{currNs}.1.name", 'bri'

      # TODO
      it 'should not propagate transactions that involve paths outside of the `only` query param'
        # TODO Note this is a stronger requirement than "should not
        # assign properties" because we want to hide data for security
        # reasons

      it 'should not propagate transactions that involve paths in the `except` query param'

      it 'should proapgate transactions that involve a query-matching doc if the transaction involves a path in the `only` query param'

      it 'should propagate transactions that involve a query-matching doc if the transaction involves a path not in the `exclude` query param'

    describe 'paginated queries', ->

      players = null
      beforeEach (done) ->
        players = [
          {id: '1', name: {last: 'Nadal',   first: 'Rafael'}, ranking: 2}
          {id: '2', name: {last: 'Federer', first: 'Roger'},  ranking: 3}
          {id: '3', name: {last: 'Djoker',  first: 'Novak'},  ranking: 1}
        ]
        forEach players, (player, callback) ->
          store.set "#{currNs}.#{player.id}", player, null, callback
        , done

      describe 'for non-saturated result sets (e.g., limit=10, sizeof(resultSet) < 10)', ->
        it 'should add a document that satisfies the query', (done) ->
          fullSetup {store},
            modelHello:
              server: (modelHello, finish) ->
                query = modelHello.query(currNs).where('ranking').gte(3).limit(2)
                modelHello.subscribe query, ->
                  expect(modelHello.get "#{currNs}.1").to.equal undefined
                  expect(modelHello.get "#{currNs}.2").to.not.equal undefined
                  expect(modelHello.get "#{currNs}.3").to.equal undefined
                  finish()
              browser: (modelHello, finish) ->
                modelHello.on 'addDoc', ->
                  expect(modelHello.get "#{currNs}.1").to.not.equal undefined
                  expect(modelHello.get "#{currNs}.2").to.not.equal undefined
                  expect(modelHello.get "#{currNs}.3").to.equal undefined
                  finish()
            modelFoo:
              server: (modelFoo, finish) -> finish()
              browser: (modelFoo, finish) ->
                modelFoo.set "#{currNs}.1.ranking", 4
                finish()
          , done

        it 'should remove a document that no longer satisfies the query', (done) ->
          fullSetup {store},
            modelHello:
              server: (modelHello, finish) ->
                query = modelHello.query(currNs).where('ranking').lt(2).limit(2)
                modelHello.subscribe query, ->
                  expect(modelHello.get "#{currNs}.1").to.equal undefined
                  expect(modelHello.get "#{currNs}.2").to.equal undefined
                  expect(modelHello.get "#{currNs}.3").to.not.equal undefined
                  finish()
              browser: (modelHello, finish) ->
                modelHello.on 'rmDoc', ->
                  expect(modelHello.get "#{currNs}.1").to.equal undefined
                  expect(modelHello.get "#{currNs}.2").to.equal undefined
                  expect(modelHello.get "#{currNs}.3").to.equal undefined
                  finish()
            modelFoo:
              server: (modelFoo, finish) -> finish()
              browser: (modelFoo, finish) ->
                modelFoo.set "#{currNs}.3.ranking", 2
                finish()
          , done

      # TODO Test multi-param sorts
      describe 'for saturated result sets (i.e., limit == sizeof(resultSet))', ->

        it 'should shift a member out and push a member in when a prev page document fails to satisfy the query', (done) ->
        #   <page prev> <page curr> <page next>
        #       -                                 shift from curr to prev
        #                                         push to curr from right
          newPlayers = [
            {id: '4', name: {first: 'David', last: 'Ferrer'}, ranking: 5}
            {id: '5', name: {first: 'Andy',  last: 'Murray'}, ranking: 4}
          ]
          allPlayers = players.concat newPlayers
          forEach newPlayers, (player, callback) ->
            store.set "#{currNs}.#{player.id}", player, null, callback
          , ->
            fullSetup {store},
              modelHello:
                server: (modelHello, finish) ->
                  query = modelHello.query(currNs).where('ranking').lte(5).sort('ranking', 'asc').limit(2).skip(2)
                  modelHello.subscribe query, ->
                    for player in allPlayers
                      if player.ranking not in [3, 4]
                        expect(modelHello.get "#{currNs}." + player.id).to.equal undefined
                      else
                        expect(modelHello.get "#{currNs}." + player.id).to.eql player
                    finish()
                browser: (modelHello, finish) ->
                  forEach ['rmDoc', 'addDoc'], (event, callback) ->
                    modelHello.on event, -> callback()
                  , ->
                    modelPlayers = modelHello.get currNs
                    for _, player of modelPlayers
                      expect(player.ranking).to.be.within 4, 5
                    finish()
              modelFoo:
                server: (modelFoo, finish) -> finish()
                browser: (modelFoo, finish) ->
                  modelFoo.set "#{currNs}.1.ranking", 6
                  finish()
            , done

        it 'should shift a member out and push a member in when a prev page document mutates in a way forcing it to move to the current page to maintain order', (done) ->
        #   <page prev> <page curr> <page next>
        #       -   >>>>>   +                     shift from curr to prev
        #                                         insert + in curr
          newPlayers = [
            {id: '4', name: {first: 'David', last: 'Ferrer'}, ranking: 6}
            {id: '5', name: {first: 'Andy',  last: 'Murray'}, ranking: 4}
          ]
          allPlayers = players.concat newPlayers
          forEach newPlayers, (player, callback) ->
            store.set "#{currNs}.#{player.id}", player, null, callback
          , ->
            fullSetup {store},
              modelHello:
                server: (modelHello, finish) ->
                  query = modelHello.query(currNs).where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
                  modelHello.subscribe query, ->
                    for player in allPlayers
                      if player.ranking not in [3, 4]
                        expect(modelHello.get "#{currNs}." + player.id).to.equal undefined
                      else
                        expect(modelHello.get "#{currNs}." + player.id).to.eql player
                    finish()
                browser: (modelHello, finish) ->
                  forEach ['rmDoc', 'addDoc'], (event, callback) ->
                    modelHello.on event, ->
                      callback()
                  , ->
                    modelPlayers = modelHello.get currNs
                    for _, player of modelPlayers
                      expect(player.ranking).to.be.within 4, 5
                    finish()
              modelFoo:
                server: (modelFoo, finish) -> finish()
                browser: (modelFoo, finish) ->
                  modelFoo.set "#{currNs}.1.ranking", 5
                  finish()
            , done

        it 'should shift a member out and push a member in when a prev page document mutates in a way forcing it to move to a subsequent page to maintain order', (done) ->
        #   <page prev> <page curr> <page next>
        #       -   >>>>>>>>>>>>>>>>>   +         shift from curr to prev
        #                                         push from next to curr
          newPlayers = [
            {id: '4', name: {first: 'David', last: 'Ferrer'}, ranking: 5}
            {id: '5', name: {first: 'Andy',  last: 'Murray'}, ranking: 4}
          ]
          allPlayers = players.concat newPlayers
          forEach newPlayers, (player, callback) ->
            store.set "#{currNs}.#{player.id}", player, null, callback
          , ->
            fullSetup {store},
              modelHello:
                server: (modelHello, finish) ->
                  query = modelHello.query(currNs).where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
                  modelHello.subscribe query, ->
                    for player in allPlayers
                      if player.ranking not in [3, 4]
                        expect(modelHello.get "#{currNs}." + player.id).to.equal undefined
                      else
                        expect(modelHello.get "#{currNs}." + player.id).to.eql player
                    finish()
                browser: (modelHello, finish) ->
                  forEach ['rmDoc', 'addDoc'], (event, callback) ->
                    modelHello.on event, -> callback()
                  , ->
                    modelPlayers = modelHello.get currNs
                    for _, player of modelPlayers
                      expect(player.ranking).to.be.within 4, 5
                    finish()
              modelFoo:
                server: (modelFoo, finish) -> finish()
                browser: (modelFoo, finish) ->
                  modelFoo.set "#{currNs}.1.ranking", 6
                  finish()
            , done

        it 'should move an existing result from a prev page if a mutation causes a new member to be added to the prev page', (done) ->
        #   <page prev> <page curr> <page next>
        #       +                                 unshift to curr from prev
        #                                         pop from curr to next
          newPlayers = [
            {id: '4', name: {first: 'David', last: 'Ferrer'}, ranking: 5}
            {id: '5', name: {first: 'Andy',  last: 'Murray'}, ranking: 4}
          ]
          allPlayers = players.concat newPlayers
          forEach newPlayers, (player, callback) ->
            store.set "#{currNs}.#{player.id}", player, null, callback
          , ->
            fullSetup {store},
              modelHello:
                server: (modelHello, finish) ->
                  query = modelHello.query(currNs).where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
                  modelHello.subscribe query, ->
                    for player in allPlayers
                      if player.ranking not in [3, 4]
                        expect(modelHello.get "#{currNs}." + player.id).to.equal undefined
                      else
                        expect(modelHello.get "#{currNs}." + player.id).to.eql player
                    finish()
                browser: (modelHello, finish) ->
                  forEach ['rmDoc', 'addDoc'], (event, callback) ->
                    modelHello.on event, -> callback()
                  , ->
                    modelPlayers = modelHello.get currNs
                    for _, player of modelPlayers
                      expect(player.ranking).to.be.within 2, 3
                    finish()
              modelFoo:
                server: (modelFoo, finish) -> finish()
                browser: (modelFoo, finish) ->
                  modelFoo.set "#{currNs}.6", {id: '6', name: {first: 'Pete', last: 'Sampras'}, ranking: 0}
                  finish()
            , done

        it 'should move the last member of the prev page to the curr page, if a curr page member mutates in a way that moves it to a prev page', (done) ->
        #   <page prev> <page curr> <page next>
        #       +   <<<<<   -                     unshift to curr from prev
          newPlayers = [
            {id: '4', name: {first: 'David', last: 'Ferrer'}, ranking: 5}
            {id: '5', name: {first: 'Andy',  last: 'Murray'}, ranking: 4}
          ]
          allPlayers = players.concat newPlayers
          forEach newPlayers, (player, callback) ->
            store.set "#{currNs}.#{player.id}", player, null, callback
          , ->
            fullSetup {store},
              modelHello:
                server: (modelHello, finish) ->
                  query = modelHello.query(currNs).where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
                  modelHello.subscribe query, ->
                    for player in allPlayers
                      if player.ranking not in [3, 4]
                        expect(modelHello.get "#{currNs}." + player.id).to.equal undefined
                      else
                        expect(modelHello.get "#{currNs}." + player.id).to.eql player
                    finish()
                browser: (modelHello, finish) ->
                  forEach ['rmDoc', 'addDoc'], (event, callback) ->
                    modelHello.on event, -> callback()
                  , ->
                    modelPlayers = modelHello.get currNs
                    for _, player of modelPlayers
                      expect(player.ranking).to.be.within 2, 3
                    finish()
              modelFoo:
                server: (modelFoo, finish) -> finish()
                browser: (modelFoo, finish) ->
                  modelFoo.set "#{currNs}.5.ranking", 0
                  finish()
            , done

        it 'should do nothing to the curr page if mutations only add docs to subsequent pages', (done) ->
        #   <page prev> <page curr> <page next>
        #                               +         do nothing to curr
          newPlayers = [
            {id: '4', name: {first: 'David', last: 'Ferrer'}, ranking: 10}
            {id: '5', name: {first: 'Andy',  last: 'Murray'}, ranking: 4}
          ]
          allPlayers = players.concat newPlayers
          forEach newPlayers, (player, callback) ->
            store.set "#{currNs}.#{player.id}", player, null, callback
          , ->
            fullSetup {store},
              modelHello:
                server: (modelHello, finish) ->
                  query = modelHello.query(currNs).where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
                  modelHello.subscribe query, ->
                    for player in allPlayers
                      if player.ranking not in [3, 4]
                        expect(modelHello.get "#{currNs}." + player.id).to.equal undefined
                      else
                        expect(modelHello.get "#{currNs}." + player.id).to.eql player
                    finish()
                browser: (modelHello, finish) ->
                  setTimeout ->
                    for player in allPlayers
                      if player.ranking not in [3, 4]
                        expect(modelHello.get "#{currNs}." + player.id).to.equal undefined
                      else
                        expect(modelHello.get "#{currNs}." + player.id).to.eql player
                    finish()
                  , 200
                  modelHello.on 'addDoc', -> finish() # Should never be called
                  modelHello.on 'rmDoc', -> finish() # Should never be called
              modelFoo:
                server: (modelFoo, finish) -> finish()
                browser: (modelFoo, finish) ->
                  modelFoo.set "#{currNs}.4.ranking", 5
                  finish()
            , done

        it 'should do nothing to the curr page if mutations only remove docs from subsequent pages', (done) ->
        #   <page prev> <page curr> <page next>
        #                               -         do nothing to curr
          newPlayers = [
            {id: '4', name: {first: 'David', last: 'Ferrer'}, ranking: 5}
            {id: '5', name: {first: 'Andy',  last: 'Murray'}, ranking: 4}
          ]
          allPlayers = players.concat newPlayers
          forEach newPlayers, (player, callback) ->
            store.set "#{currNs}.#{player.id}", player, null, callback
          , ->
            fullSetup {store},
              modelHello:
                server: (modelHello, finish) ->
                  query = modelHello.query(currNs).where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
                  modelHello.subscribe query, ->
                    for player in allPlayers
                      if player.ranking not in [3, 4]
                        expect(modelHello.get "#{currNs}." + player.id).to.equal undefined
                      else
                        expect(modelHello.get "#{currNs}." + player.id).to.eql player
                    finish()
                browser: (modelHello, finish) ->
                  setTimeout ->
                    modelPlayers = modelHello.get currNs
                    for _, player of modelPlayers
                      expect(player.ranking).to.be.within 3, 4
                    finish()
                  , 200
                  modelHello.on 'addDoc', -> finish() # Should never be called
                  modelHello.on 'rmDoc', -> finish() # Should never be called
              modelFoo:
                server: (modelFoo, finish) -> finish()
                browser: (modelFoo, finish) ->
                  modelFoo.set "#{currNs}.4.ranking", 10
                  finish()
            , done

        it 'should replace a document (whose recent mutation makes it in-compatible with the query) if another doc in the db is compatible', (done) ->
        #   <page prev> <page curr> <page next>
        #                   -                     push to curr from next
          fullSetup {store},
            modelHello:
              server: (modelHello, finish) ->
                query = modelHello.query(currNs).where('ranking').lt(5).sort('ranking', 'asc').limit(2)
                modelHello.subscribe query, ->
                  expect(modelHello.get "#{currNs}.1").to.not.equal undefined
                  expect(modelHello.get "#{currNs}.2").to.equal undefined
                  expect(modelHello.get "#{currNs}.3").to.not.equal undefined
                  finish()
              browser: (modelHello, finish) ->
                forEach ['rmDoc', 'addDoc'], (event, callback) ->
                  modelHello.on event, -> callback()
                , ->
                  expect(modelHello.get "#{currNs}.1").to.not.equal undefined
                  expect(modelHello.get "#{currNs}.2").to.not.equal undefined
                  expect(modelHello.get "#{currNs}.3").to.equal undefined
                  finish()
            modelFoo:
              server: (modelFoo, finish) -> finish()
              browser: (modelFoo, finish) ->
                modelFoo.set "#{currNs}.3.ranking", 6
                finish()
          , done

        it 'should replace a document if another doc was just mutated so it supercedes the doc according to the query', (done) ->
          #   <page prev> <page curr> <page next>
          #                   +                     pop from curr to next
          fullSetup {store},
            modelHello:
              server: (modelHello, finish) ->
                query = modelHello.query(currNs).where('ranking').lt(3).sort('name.first', 'desc').limit(2)
                modelHello.subscribe query, ->
                  expect(modelHello.get "#{currNs}.1").to.not.equal undefined
                  expect(modelHello.get "#{currNs}.2").to.equal undefined
                  expect(modelHello.get "#{currNs}.3").to.not.equal undefined
                  finish()
              browser: (modelHello, finish) ->
                modelHello.on 'rmDoc', ->
                  expect(modelHello.get "#{currNs}.1").to.not.equal undefined
                  expect(modelHello.get "#{currNs}.2").to.not.equal undefined
                  expect(modelHello.get "#{currNs}.3").to.equal undefined
                  finish()
            modelFoo:
              server: (modelFoo, finish) -> finish()
              browser: (modelFoo, finish) ->
                modelFoo.set "#{currNs}.2.ranking", 2
                finish()
          , done

        it 'should keep a document that just re-orders the query result set', (done) ->
        #   <page prev> <page curr> <page next>
        #                   -><-                  re-arrange curr members
          fullSetup {store},
            modelHello:
              server: (modelHello, finish) ->
                query = modelHello.query(currNs).where('ranking').lt(10).sort('ranking', 'asc').limit(2)
                modelHello.subscribe query, ->
                  expect(modelHello.get "#{currNs}.1").to.not.equal undefined
                  expect(modelHello.get "#{currNs}.2").to.equal undefined
                  expect(modelHello.get "#{currNs}.3").to.not.equal undefined
                  finish()
              browser: (modelHello, finish) ->
                modelHello.on 'setPost', ->
                  expect(modelHello.get "#{currNs}.1").to.not.equal undefined
                  expect(modelHello.get "#{currNs}.2").to.equal undefined
                  expect(modelHello.get "#{currNs}.3").to.not.equal undefined
                  expect(modelHello.get "#{currNs}.1.ranking").to.equal 0
                  finish()
            modelFoo:
              server: (modelFoo, finish) -> finish()
              browser: (modelFoo, finish) ->
                modelFoo.set "#{currNs}.1.ranking", 0
                finish()
          , done

    describe 'versioning', ->
      players = null
      beforeEach (done) ->
        players = [
          {id: '1', name: {last: 'Nadal',   first: 'Rafael'}, ranking: 2}
          {id: '2', name: {last: 'Federer', first: 'Roger'},  ranking: 3}
          {id: '3', name: {last: 'Djoker',  first: 'Novak'},  ranking: 1}
        ]
        forEach players, (player, callback) ->
          store.set "#{currNs}.#{player.id}", player, null, callback
        , done

      it 'should update the version when the doc is removed from a model because it no longer matches subscriptions', (done) ->
        oldVer = null
        fullSetup {store},
          modelHello:
            server: (modelHello, finish) ->
              query = modelHello.query(currNs).where('ranking').lt(10)
              modelHello.subscribe query, ->
                oldVer = modelHello.getVer()
                finish()
            browser: (modelHello, finish) ->
              modelHello.on 'rmDoc', ->
                expect(modelHello.getVer()).to.equal(oldVer + 1)
                finish()
          modelFoo:
            server: (modelFoo, finish) -> finish()
            browser: (modelFoo, finish) ->
              modelFoo.set "#{currNs}.1.ranking", 11
              finish()
        , done

      it 'should update the version when the doc is added to a model because it starts to matche subscriptions', (done) ->
        oldVer = null
        fullSetup {store},
          modelHello:
            server: (modelHello, finish) ->
              query = modelHello.query(currNs).where('ranking').gt(2)
              modelHello.subscribe query, ->
                oldVer = modelHello.getVer()
                finish()
            browser: (modelHello, finish) ->
              modelHello.on 'addDoc', ->
                expect(modelHello.getVer()).to.equal(oldVer + 1)
                finish()
          modelFoo:
            server: (modelFoo, finish) -> finish()
            browser: (modelFoo, finish) ->
              modelFoo.set "#{currNs}.1.ranking", 11
              finish()
        , done

    describe 'transaction application', ->
      players = null
      beforeEach (done) ->
        players = [
          {id: '1', name: {last: 'Nadal',   first: 'Rafael'}, ranking: 2}
          {id: '2', name: {last: 'Federer', first: 'Roger'},  ranking: 3}
          {id: '3', name: {last: 'Djoker',  first: 'Novak'},  ranking: 1}
        ]
        forEach players, (player, callback) ->
          store.set "#{currNs}.#{player.id}", player, null, callback
        , done

      it 'should apply a txn if a document is still in a query result set after a mutation', (done) ->
        fullSetup {store},
          modelHello:
            server: (modelHello, finish) ->
              query = modelHello.query(currNs).where('ranking').equals(1)
              modelHello.subscribe query, ->
                for player in players
                  if player.ranking == 1
                    expect(modelHello.get "#{currNs}.#{player.id}").to.eql player
                  else
                    expect(modelHello.get "#{currNs}.#{player.id}").to.equal undefined
                finish()
            browser: (modelHello, finish) ->
              modelHello.on 'setPost', ->
                expect(modelHello.get "#{currNs}.3").to.eql {id: '3', name: {last: 'Djokovic', first: 'Novak'}, ranking: 1}
                finish()
          modelFoo:
            server: (modelFoo, finish) -> finish()
            browser: (modelFoo, finish) ->
              modelFoo.set "#{currNs}.3.name.last", 'Djokovic'
              finish()
        , done

      it 'should not apply a txn if a document is being added to a query result set after a mutation', (done) ->
        fullSetup {store},
          modelHello:
            server: (modelHello, finish) ->
              query = modelHello.query(currNs).where('name.last').equals('Djokovic')
              modelHello.subscribe query, ->
                for player in players
                  expect(modelHello.get "#{currNs}.#{player.id}").to.equal undefined
                finish()
            browser: (modelHello, finish) ->
              modelHello.on 'setPost', ([path, val], ver) ->
                if path == "#{currNs}.3"
                  expect(modelHello.get "#{currNs}.3").to.eql {id: '3', name: {last: 'Djokovic', first: 'Novak'}, ranking: 1}
                  finish()
                else
                  throw new Error "Should not be setting #{path}"
          modelFoo:
            server: (modelFoo, finish) -> finish()
            browser: (modelFoo, finish) ->
              modelFoo.set "#{currNs}.3.name.last", 'Djokovic'
              finish()
        , done

    describe 'over-subscribing to a doc via 2 queries', ->
      players = null
      beforeEach (done) ->
        players = [
          {id: '1', name: {last: 'Nadal',   first: 'Rafael'}, ranking: 2}
          {id: '2', name: {last: 'Federer', first: 'Roger'},  ranking: 3}
          {id: '3', name: {last: 'Djoker',  first: 'Novak'},  ranking: 1}
        ]
        forEach players, (player, callback) ->
          store.set "#{currNs}.#{player.id}", player, null, callback
        , done

      # The following is true because we only pass along transactions
      # whose version is > the socket version. The first time the socket
      # sees the transaction via pubSub, it sends it down to the browser.
      # The second time it sees the now-duplicate transaction, it doesn't
      # send it down because the txn version == socket version.
      it 'should only receive a transaction once if it applies to > 1 query', (done) ->
        txnDuplicateReceipts = 0
        fullSetup {store},
          modelHello:
            server: (modelHello, finish) ->
              queryZoo    = modelHello.query(currNs).where('ranking').lt(10)
              queryLander = modelHello.query(currNs).where('ranking').lt(9)
              modelHello.subscribe queryZoo, queryLander, ->
                finish()
            browser: (modelHello, finish) ->
              modelHello.on 'set', ([path, val], ver) ->
                if path == "#{currNs}.3.name.last"
                  expect(modelHello.get "#{currNs}.3").to.eql {id: '3', name: {last: 'Djokovic', first: 'Novak'}, ranking: 1}
                else
                  throw new Error "Should not be setting #{path}"
              modelHello.socket.on 'txn', (txn, num) ->
                finish() # This will throw an error if called twice
          modelFoo:
            server: (modelFoo, finish) -> finish()
            browser: (modelFoo, finish) ->
              setTimeout ->
                modelFoo.set "#{currNs}.3.name.last", 'Djokovic'
              , 400
              finish()
        , done

    describe 'dependent queries', ->
      it "should send updates when they react to their depedency queries' updates"
      it "should not send updates if its dependency queries emit updates that don't impact the dependent query"
