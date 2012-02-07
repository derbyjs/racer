should = require 'should'
Store = require '../src/Store'
redis = require 'redis'
async = require 'async'
{calls} = require './util'
{fullSetup} = require './util/model'
query = require '../src/query'

describe 'Live Querying', ->
  describe 'hasing', ->
    it 'should create the same hash for 2 equivalent queries that exhibit different method call ordering', ->
      q1 = query('users').where('name').equals('brian').where('age').equals(26)
      q2 = query('users').where('age').equals(26).where('name').equals('brian')
      q1.hash().should.eql q2.hash()

      q1 = query('users').where('votes').lt(20).gt(10).where('followers').gt(100).lt(200)
      q2 = query('users').where('followers').lt(200).gt(100).where('votes').gt(10).lt(20)
      q1.hash().should.eql q2.hash()

    it 'should create different hashes for different queries', ->
      q1 = query('users').where('name').equals('brian')
      q2 = query('users').where('name').equals('nate')
      q1.hash().should.not.eql q2.hash()

  adapters =
    Mongo: ->
      MongoAdapter = require '../src/adapters/Mongo'
      mongo = new MongoAdapter 'mongodb://localhost/database'
      mongo.connect()
      return mongo

  for adapterName, adapterBuilder of adapters
    do (adapterName, adapterBuilder) ->
      describe "with #{adapterName}", ->
        store = null

        beforeEach ->
          adapter = adapterBuilder()
          # Can't make this a `before` callback because redis pub/sub
          # may bleed from one test into the next
          store = new Store {adapter}

        afterEach (done) ->
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
            async.forEach users
            , (user, callback) ->
              store.set "users.#{user.id}", user, null, callback
            , done

          it 'should work for one parameter `equals` queries', (done) ->
            model = store.createModel()
            query = model.query('users').where('name').equals('brian')
            model.subscribe query, ->
              model.get('users.0').should.eql users[0]
              should.equal undefined, model.get('users.1')
              should.equal undefined, model.get('users.2')
              done()

          it 'should work for one parameter `gt` queries', (done) ->
            model = store.createModel()
            query = model.query('users').where('age').gt(25)
            model.subscribe query, ->
              should.equal undefined, model.get('users.0')
              for i in [1, 2]
                model.get('users.' + i).should.eql users[i]
              done()

          it 'should work for one parameter `gte` queries', (done) ->
            model = store.createModel()
            query = model.query('users').where('age').gte(26)
            model.subscribe query, ->
              should.equal undefined, model.get('users.0')
              for i in [1, 2]
                model.get('users.' + i).should.eql users[i]
              done()

          it 'should work for one parameter `lt` queries', (done) ->
            model = store.createModel()
            query = model.query('users').where('age').lt(27)
            model.subscribe query, ->
              for i in [0, 1]
                model.get('users.' + i).should.eql users[i]
              should.equal undefined, model.get('users.2')
              done()

          it 'should work for one parameter `lte` queries', (done) ->
            model = store.createModel()
            query = model.query('users').where('age').lte(26)
            model.subscribe query, ->
              for i in [0, 1]
                model.get('users.' + i).should.eql users[i]
              should.equal undefined, model.get('users.2')
              done()

          it 'should work for one parameter `within` queries', (done) ->
            model = store.createModel()
            query = model.query('users').where('name').within(['brian', 'x'])
            model.subscribe query, ->
              for i in [0, 2]
                model.get('users.' + i).should.eql users[i]
              should.equal undefined, model.get('users.1')
              done()

          it 'should work for one parameter `contains` scalar queries', (done) ->
            model = store.createModel()
            query = model.query('users').where('workdays').contains(['mon', 'wed'])
            model.subscribe query, ->
              for i in [0, 1]
                model.get('users.' + i).should.eql users[i]
              should.equal undefined, model.get('users.2')
              done()

          it 'should work for compound queries', (done) ->
            model = store.createModel()
            query = model.query('users').where('workdays').contains(['wed']).where('age').gt(25)
            model.subscribe query, ->
              for i in [0, 2]
                should.equal undefined, model.get('users.' + i)
              model.get('users.1').should.eql users[1]
              done()

          it 'should only retrieve paths specified in `only`', (done) ->
            model = store.createModel()
            query = model.query('users').where('age').gt(20).only('name', 'age')
            model.subscribe query, ->
              for i in [0..2]
                model.get('users.' + i + '.id').should.equal users[i].id
                model.get('users.' + i + '.name').should.equal users[i].name
                model.get('users.' + i + '.age').should.equal users[i].age
                should.equal undefined, model.get('users.' + i + '.workdays')
              done()

          it 'should exclude paths specified in `except`', (done) ->
            model = store.createModel()
            query = model.query('users').where('age').gt(20).except('name', 'workdays')
            model.subscribe query, ->
              for i in [0..2]
                model.get('users.' + i + '.id').should.equal users[i].id
                model.get('users.' + i + '.age').should.equal users[i].age
                should.equal undefined, model.get('users.' + i + '.name')
                should.equal undefined, model.get('users.' + i + '.workdays')
              done()

        describe 'receiving proper publishes', ->
          describe 'set <namespace>.<id>', ->
            it 'should publish the txn *only* to relevant live `equals` queries', calls 2, (done) ->
              modelLeo = store.createModel()
              queryLeo = modelLeo.query('users').where('name').equals('leo')

              modelBill = store.createModel()
              queryBill = modelBill.query('users').where('name').equals('bill')

              modelLeo.subscribe queryLeo, ->
                modelLeo.on 'set', 'users.*', (id, user) ->
                  id.should.equal '1'
                  user.should.eql userLeo
                  done()

              modelBill.subscribe queryBill, ->
                modelBill.on 'set', 'users.*', (id, user) ->
                  id.should.equal '2'
                  user.should.eql userBill
                  done()

              userLeo  = id: '1', name: 'leo'
              userBill = id: '2', name: 'bill'
              userSue  = id: '3', name: 'sue'
              ver = 0
              modelSue = store.createModel()
              modelSue.set 'users.1', userLeo
              modelSue.set 'users.2', userBill
              modelSue.set 'users.3', userSue

          test = ({initialDoc, queries, preCondition, postCondition, mutate, listenForMutation}) ->
            return (done) ->
              fullSetup {store},
                modelHello:
                  server: (modelHello, finish) ->
                    [key, doc] = initialDoc
                    store.set key, doc, null, ->
                      modelHello.subscribe queries(modelHello.query)..., ->
                        preCondition(modelHello)
                        finish()
                  browser: (modelHello, finish) ->
                    preCondition modelHello
                    listenForMutation modelHello, ->
                      switch postCondition.length
                        when 1 then postCondition modelHello
                        when 2 then postCondition modelHello, finish
                      finish()
                    , finish
                modelFoo:
                  server: (_, finish) -> finish()
                  browser: (modelFoo, finish) ->
                    mutate modelFoo
                    finish()
              , done

          describe 'set <namespace>.<id>.*', ->
            describe 'for equals queries', ->
              it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', greeting: 'foo'}]
                queries: (query) ->
                  return [
                    query('users').where('greeting').equals('hello')
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'addDoc', onMutation
                preCondition: (subscriberModel) ->
                  should.equal undefined, subscriberModel.get 'users.1'
                postCondition: (subscriberBrowserModel) ->
                   subscriberBrowserModel.get('users.1').should.eql {id: '1', greeting: 'hello'}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.set 'users.1.greeting', 'hello'

              it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', greeting: 'foo'}]
                queries: (query) ->
                  return [query('users').where('greeting').equals('foo')]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'rmDoc', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', greeting: 'foo'}
                postCondition: (subscriberBrowserModel) ->
                  should.equal undefined, subscriberBrowserModel.get 'users.1'
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.set 'users.1.greeting', 'hello'

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
                 'and (2) a query matching the doc both pre- and post-mutation', test
                initialDoc: ['users.1', {id: '1', greeting: 'foo', age: 21}]
                queries: (query) ->
                  return [
                    query('users').where('greeting').equals('foo')
                    query('users').where('age').equals(21)
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'setPost', ([path, val]) ->
                    if path == 'users.1.greeting' && val == 'hello' then onMutation()
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', greeting: 'foo', age: 21}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', greeting: 'hello', age: 21}
                  subscriberBrowserModel.on 'rmDoc', ->
                    # This should never get called. Keep it here to detect if we call > 1
                    throw new Error 'Should not rmDoc'
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.set 'users.1.greeting', 'hello'

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
                 ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', age: 27}]
                queries: (query) ->
                  return [
                    query('users').where('age').equals(27)
                    query('users').where('age').equals(28)
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'rmDoc', ->
                    # This should never get called. Keep it here to detect if we call > 1
                    throw new Error 'Should not rmDoc'
                  subscriberBrowserModel.on 'setPost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', age: 27}
                postCondition: (subscriberBrowserModel, finish) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', age: 28}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.set 'users.1.age', 28

            describe 'for gt queries', ->
              it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', age: 27}]
                queries: (query) -> [query('users').where('age').gt(27)]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'addDoc', onMutation
                preCondition: (subscriberModel) ->
                  should.equal undefined, subscriberModel.get 'users.1'
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', age: 28}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.set 'users.1.age', 28

              it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', age: 28}]
                queries: (query) -> [query('users').where('age').gt(27)]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'rmDoc', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', age: 28}
                postCondition: (subscriberBrowserModel) ->
                  should.equal undefined, subscriberBrowserModel.get 'users.1'
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.set 'users.1.age', 27

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
                 'and (2) a query matching the doc both pre- and post-mutation', test
                initialDoc: ['users.1', {id: '1', age: 23}]
                queries: (query) ->
                  return [
                    query('users').where('age').gt(21)
                    query('users').where('age').gt(22)
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation, finish) ->
                  subscriberBrowserModel.on 'setPost', onMutation
                  subscriberBrowserModel.on 'rmDoc', ->
                    throw new Error 'Should not rmDoc'
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', age: 23}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', age: 22}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.set 'users.1.age', 22

          # TODO gte, lt, lte queries testing

            describe 'for within queries', ->
              it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', age: 27}]
                queries: (query) -> [query('users').where('age').within([28, 29, 30])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'addDoc', onMutation
                preCondition: (subscriberModel) ->
                  should.equal undefined, subscriberModel.get 'users.1'
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', age: 30}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.set 'users.1.age', 30

              it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', age: 27}]
                queries: (query) -> [query('users').where('age').within([27, 28])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'rmDoc', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', age: 27}
                postCondition: (subscriberBrowserModel) ->
                  should.equal undefined, subscriberBrowserModel.get 'users.1'
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.set 'users.1.age', 29

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation'+
                 'and (2) a query matching the doc both pre- and post-mutation', test
                initialDoc: ['users.1', {id: '1', age: 27}]
                queries: (query) ->
                  return [
                    query('users').where('age').within([27, 28])
                    query('users').where('age').within([27, 30])
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'setPost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', age: 27}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', age: 30}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.set 'users.1.age', 30

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
                 ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', age: 27}]
                queries: (query) ->
                  return [
                    query('users').where('age').within([27, 29])
                    query('users').where('age').within([28, 29])
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'rmDoc', ->
                    # This should never get called. Keep it here to detect if we call > 1
                    throw new Error 'Should not rmDoc'
                  subscriberBrowserModel.on 'setPost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', age: 27}
                postCondition: (subscriberBrowserModel, finish) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', age: 28}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.set 'users.1.age', 28

          describe 'del <namespace>.<id>', ->
            it 'should remove the modified doc from any models subscribed to a query matching the doc pre-del', test
              initialDoc: ['users.1', {id: '1', age: 28}]
              queries: (query) -> [query('users').where('age').equals(28)]
              listenForMutation: (subscriberBrowserModel, onMutation) ->
                subscriberBrowserModel.on 'rmDoc', onMutation
              preCondition: (subscriberModel) ->
                subscriberModel.get('users.1').should.eql {id: '1', age: 28}
              postCondition: (subscriberBrowserModel) ->
                should.equal undefined, subscriberBrowserModel.get 'users.1'
              mutate: (publisherBrowserModel) ->
                publisherBrowserModel.del 'users.1'

          describe 'del <namespace>.<id>.*', ->
            it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
              initialDoc: ['users.1', {id: '1', name: 'Brian'}]
              queries: (query) -> [query('users').where('name').notEquals('Brian')]
              listenForMutation: (subscriberBrowserModel, onMutation) ->
                subscriberBrowserModel.on 'addDoc', onMutation
              preCondition: (subscriberModel) ->
                should.equal undefined, subscriberModel.get 'users.1'
              postCondition: (subscriberBrowserModel) ->
                subscriberBrowserModel.get 'users.1', {id: '1'}
              mutate: (publisherBrowserModel) ->
                publisherBrowserModel.del 'users.1.name'

            it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
              initialDoc: ['users.1', {id: '1', name: 'Brian'}]
              queries: (query) -> [query('users').where('name').equals('Brian')]
              listenForMutation: (subscriberBrowserModel, onMutation) ->
                subscriberBrowserModel.on 'rmDoc', onMutation
              preCondition: (subscriberModel) ->
                subscriberModel.get('users.1').should.eql {id: '1', name: 'Brian'}
              postCondition: (subscriberBrowserModel) ->
                should.equal undefined, subscriberBrowserModel.get 'users.1'
              mutate: (publisherBrowserModel) ->
                publisherBrowserModel.del 'users.1.name'

            it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation' + 
               'and (2) a query matching the doc both pre- and post-mutation', test
              initialDoc: ['users.1', {id: '1', name: 'Brian', age: 27}]
              queries: (query) ->
                return [
                  query('users').where('name').equals('Brian')
                  query('users').where('age').equals(27)
                ]
              listenForMutation: (subscriberBrowserModel, onMutation) ->
                subscriberBrowserModel.on 'rmDoc', ->
                  throw new Error 'Should not rmDoc'
                subscriberBrowserModel.on 'delPost', onMutation
              preCondition: (subscriberModel) ->
                subscriberModel.get('users.1').should.eql {id: '1', name: 'Brian', age: 27}
              postCondition: (subscriberBrowserModel) ->
                subscriberBrowserModel.get('users.1').should.eql {id: '1', name: 'Brian'}
              mutate: (publisherBrowserModel) ->
                publisherBrowserModel.del 'users.1.age'

            it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
               ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
              initialDoc: ['users.1', {id: '1', name: 'Brian'}]
              queries: (query) ->
                return [
                  query('users').where('name').equals('Brian')
                  query('users').where('name').notEquals('Brian')
                ]
              listenForMutation: (subscriberBrowserModel, onMutation) ->
                subscriberBrowserModel.on 'rmDoc', ->
                  throw new Error 'Should not rmDoc'
                subscriberBrowserModel.on 'addDoc', ->
                  throw new Error 'Should not addDoc'
                subscriberBrowserModel.on 'delPost', onMutation
              preCondition: (subscriberModel) ->
                subscriberModel.get('users.1').should.eql {id: '1', name: 'Brian'}
              postCondition: (subscriberBrowserModel) ->
                subscriberBrowserModel.get('users.1').should.eql {id: '1'}
              mutate: (publisherBrowserModel) ->
                publisherBrowserModel.del 'users.1.name'

          describe 'incr', ->

          describe 'push', ->
            describe 'for contains queries', ->
              it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['hi', 'ho']}]
                queries: (query) -> [query('users').where('tags').contains(['hi', 'there'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'addDoc', onMutation
                preCondition: (subscriberModel) ->
                  should.equal undefined, subscriberModel.get('users.1')
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['hi', 'ho', 'there']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.push 'users.1.tags', 'there'

              it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation (where the push occurs on undefined)', test
                initialDoc: ['users.1', {id: '1'}]
                queries: (query) -> [query('users').where('tags').contains(['hi'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'addDoc', onMutation
                preCondition: (subscriberModel) ->
                  should.equal undefined, subscriberModel.get('users.1')
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['hi']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.push 'users.1.tags', 'hi'

              it 'should keep the modified doc for any models subscribed to a query matching the doc both pre- and post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['hi', 'there']}]
                queries: (query) -> [query('users').where('tags').contains(['there', 'hi'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'pushPost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['hi', 'there']}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['hi', 'there', 'yo']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.push 'users.1.tags', 'yo'

            describe 'for equals queries', ->
              it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['red']}]
                queries: (query) -> [query('users').where('tags').equals(['red', 'alert'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'addDoc', onMutation
                preCondition: (subscriberModel) ->
                  should.equal undefined, subscriberModel.get 'users.1'
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['red', 'alert']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.push 'users.1.tags', 'alert'

              it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['red']}]
                queries: (query) -> [query('users').where('tags').equals(['red'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'rmDoc', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['red']}
                postCondition: (subscriberBrowserModel) ->
                  should.equal undefined, subscriberBrowserModel.get 'users.1'
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.push 'users.1.tags', 'alert'

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
                 'and (2) a query matching the doc both pre- and post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['command']}]
                queries: (query) ->
                  return [
                    query('users').where('tags').equals(['command', 'and', 'conquer'])
                    query('users').where('tags').contains(['command'])
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'pushPost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['command']}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['command', 'and', 'conquer']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.push 'users.1.tags', 'and', 'conquer'

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
                 ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: [{a: 1, b: 2}]}]
                queries: (query) ->
                  return [
                    query('users').where('tags').equals [{a: 1, b: 2}]
                    query('users').where('tags').contains [{c: 10, d: 11}, {a: 1, b: 2}]
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'pushPost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: [{a: 1, b: 2}]}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: [{a: 1, b: 2}, {c: 10, d: 11}]}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.push 'users.1.tags', {c: 10, d: 11}

          describe 'unshift', ->
            describe 'for contains queries', ->
              it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['ho', 'there']}]
                queries: (query) -> [query('users').where('tags').contains(['hi', 'ho'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'addDoc', onMutation
                preCondition: (subscriberModel) ->
                  should.equal undefined, subscriberModel.get('users.1')
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['hi', 'ho', 'there']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.unshift 'users.1.tags', 'hi'

              it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation (where the push occurs on undefined)', test
                initialDoc: ['users.1', {id: '1'}]
                queries: (query) -> [query('users').where('tags').contains(['hi'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'addDoc', onMutation
                preCondition: (subscriberModel) ->
                  should.equal undefined, subscriberModel.get('users.1')
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['hi']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.unshift 'users.1.tags', 'hi'

              it 'should keep the modified doc for any models subscribed to a query matching the doc both pre- and post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['hi', 'there']}]
                queries: (query) -> [query('users').where('tags').contains(['there', 'hi'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'unshiftPost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['hi', 'there']}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['yo', 'hi', 'there']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.unshift 'users.1.tags', 'yo'

            describe 'for equals queries', ->

          describe 'insert', ->
            describe 'for contains queries', ->
              it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['ho', 'there']}]
                queries: (query) -> [query('users').where('tags').contains(['hi', 'ho'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'addDoc', onMutation
                preCondition: (subscriberModel) ->
                  should.equal undefined, subscriberModel.get('users.1')
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['ho', 'hi', 'there']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.insert 'users.1.tags', 1, 'hi'

              it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation (where the push occurs on undefined)', test
                initialDoc: ['users.1', {id: '1'}]
                queries: (query) -> [query('users').where('tags').contains(['hi'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'addDoc', onMutation
                preCondition: (subscriberModel) ->
                  should.equal undefined, subscriberModel.get('users.1')
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['hi']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.insert 'users.1.tags', 0, 'hi'

              it 'should keep the modified doc for any models subscribed to a query matching the doc both pre- and post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['hi', 'there']}]
                queries: (query) -> [query('users').where('tags').contains(['there', 'hi'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'insertPost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['hi', 'there']}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['hi', 'yo', 'there']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.insert 'users.1.tags', 1, 'yo'

            describe 'for equals queries', ->

          describe 'pop', ->
            describe 'for contains queries', ->
              it 'should remove the modified doc from any models subscribed to a query matching the doc preo-mutation but not matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['red', 'orange']}]
                queries: (query) -> [query('users').where('tags').contains(['red', 'orange'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'rmDoc', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['red', 'orange']}
                postCondition: (subscriberBrowserModel) ->
                  should.equal undefined, subscriberBrowserModel.get 'users.1'
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.pop 'users.1.tags'

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation' +
                 'and (2) a query matching the doc both pre- and post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['venti', 'grande']}]
                queries: (query) ->
                  return [
                    query('users').where('tags').contains(['venti', 'grande'])
                    query('users').where('tags').contains(['venti'])
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'popPost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['venti', 'grande']}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['venti']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.pop 'users.1.tags'

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
                 ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['walter', 'white']}]
                queries: (query) ->
                  return [
                    query('users').where('tags').contains(['walter', 'white'])
                    query('users').where('tags').equals(['walter'])
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'popPost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['walter', 'white']}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['walter']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.pop 'users.1.tags'

            describe 'for equals queries', ->

          describe 'shift', ->
            describe 'for contains queries', ->
              it 'should remove the modified doc from any models subscribed to a query matching the doc preo-mutation but not matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['red', 'orange']}]
                queries: (query) -> [query('users').where('tags').contains(['red', 'orange'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'rmDoc', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['red', 'orange']}
                postCondition: (subscriberBrowserModel) ->
                  should.equal undefined, subscriberBrowserModel.get 'users.1'
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.shift 'users.1.tags'

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation' +
                 'and (2) a query matching the doc both pre- and post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['venti', 'grande']}]
                queries: (query) ->
                  return [
                    query('users').where('tags').contains(['venti', 'grande'])
                    query('users').where('tags').contains(['grande'])
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'shiftPost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['venti', 'grande']}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['grande']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.shift 'users.1.tags'

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
                 ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['walter', 'white']}]
                queries: (query) ->
                  return [
                    query('users').where('tags').contains(['walter', 'white'])
                    query('users').where('tags').equals(['white'])
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'shiftPost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['walter', 'white']}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['white']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.shift 'users.1.tags'

            describe 'for equals queries', ->

          describe 'remove', ->
            describe 'for contains queries', ->
              it 'should remove the modified doc from any models subscribed to a query matching the doc preo-mutation but not matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['red', 'orange', 'yellow']}]
                queries: (query) -> [query('users').where('tags').contains(['red', 'orange'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'rmDoc', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['red', 'orange', 'yellow']}
                postCondition: (subscriberBrowserModel) ->
                  should.equal undefined, subscriberBrowserModel.get 'users.1'
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.remove 'users.1.tags', 1, 1

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation' +
                 'and (2) a query matching the doc both pre- and post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['piquito', 'venti', 'grande']}]
                queries: (query) ->
                  return [
                    query('users').where('tags').contains(['venti', 'grande'])
                    query('users').where('tags').contains(['grande'])
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'removePost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['piquito', 'venti', 'grande']}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['piquito', 'grande']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.remove 'users.1.tags', 1, 1

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
                 ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['walter', 'jesse', 'white']}]
                queries: (query) ->
                  return [
                    query('users').where('tags').contains(['walter', 'white'])
                    query('users').where('tags').equals(['white', 'white'])
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'removePost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['walter', 'jesse', 'white']}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['walter', 'white']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.remove 'users.1.tags', 1, 1

          describe 'move', ->
            describe 'for equals queries', ->
              it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['alert', 'red']}]
                queries: (query) -> [query('users').where('tags').equals(['red', 'alert'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'addDoc', onMutation
                preCondition: (subscriberModel) ->
                  should.equal undefined, subscriberModel.get 'users.1'
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['red', 'alert']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.move 'users.1.tags', 0, 1

              it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['red', 'alert']}]
                queries: (query) -> [query('users').where('tags').equals(['red', 'alert'])]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'rmDoc', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['red', 'alert']}
                postCondition: (subscriberBrowserModel) ->
                  should.equal undefined, subscriberBrowserModel.get 'users.1'
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.push 'users.1.tags', 1, 0

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
                 'and (2) a query matching the doc both pre- and post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: ['command', 'and', 'conquer']}]
                queries: (query) ->
                  return [
                    query('users').where('tags').equals(['command', 'and', 'conquer'])
                    query('users').where('tags').contains(['conquer', 'command', 'and'])
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'movePost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: ['command', 'and', 'conquer']}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: ['conquer', 'command', 'and']}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.move 'users.1.tags', 2, 0

              it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
                 ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation', test
                initialDoc: ['users.1', {id: '1', tags: [{a: 1}, {b: 2}, {c: 3}]}]
                queries: (query) ->
                  return [
                    query('users').where('tags').equals [{a: 1}, {b: 2}, {c: 3}]
                    query('users').where('tags').equals [{a: 1}, {c: 3}, {b: 2}]
                  ]
                listenForMutation: (subscriberBrowserModel, onMutation) ->
                  subscriberBrowserModel.on 'movePost', onMutation
                preCondition: (subscriberModel) ->
                  subscriberModel.get('users.1').should.eql {id: '1', tags: [{a: 1}, {b: 2}, {c: 3}]}
                postCondition: (subscriberBrowserModel) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', tags: [{a: 1}, {c: 3}, {b: 2}]}
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.move 'users.1.tags', 2, 1

          describe 'only queries', ->
            # TODO
            it 'should not propagate properties not in `only`'#, test
#              # TODO Note this is a stronger requirement than "should not
#              # assign properties" because we want to hide data for security
#              # reasons
#              initialDoc: ['users.1', {id: '1', name: 'brian', age: 26, city: 'sf'}]
#              queries: (query) -> [query('users').where('name').equals('bri').only('name', 'city')]
#              listenForMutation: (subscriberBrowserModel, onMutation) ->
#                subscriberBrowserModel.on 'addDoc', onMutation
#              preCondition: (subscriberModel) ->
#                should.equal undefined, subscriberModel.get('users.1')
#              postCondition: (subscriberBrowserModel) ->
#                subscriberBrowserModel.get('users.1').should.eql {id: '1', name: 'bri', city: 'sf'}
#              mutate: (publisherBrowserModel) ->
#                publisherBrowserModel.set 'users.1.name', 'bri'

            # TODO
            it 'should not propagate transactions that involve paths outside of the `only` query param'
              # TODO Note this is a stronger requirement than "should not
              # assign properties" because we want to hide data for security
              # reasons

            it 'should not propagate transactions that involve paths in the `except` query param'

            it 'should proapgate transactions that involve a query-matching doc if the transaction involves a path in the `only` query param'

            it 'should propagate transactions that involve a query-matching doc if the transaction involves a path not in the `exclude` query param'

          describe 'paginated queries', ->

            players = [
              {id: '1', name: {last: 'Nadal',   first: 'Rafael'}, ranking: 2}
              {id: '2', name: {last: 'Federer', first: 'Roger'},  ranking: 3}
              {id: '3', name: {last: 'Djoker',  first: 'Novak'},  ranking: 1}
            ]
            beforeEach (done) ->
              async.forEach players
              , (player, callback) ->
                store.set "players.#{player.id}", player, null, callback
              , done

            describe 'for non-saturated result sets (e.g., limit=10, sizeof(resultSet) < 10)', ->
              it 'should add a document that satisfies the query', (done) ->
                fullSetup {store},
                  modelHello:
                    server: (modelHello, finish) ->
                      query = modelHello.query('players').where('ranking').gte(3).limit(2)
                      modelHello.subscribe query, ->
                        should.equal    undefined, modelHello.get('players.1')
                        should.notEqual undefined, modelHello.get('players.2')
                        should.equal    undefined, modelHello.get('players.3')
                        finish()
                    browser: (modelHello, finish) ->
                      modelHello.on 'addDoc', ->
                        should.notEqual undefined, modelHello.get('players.1')
                        should.notEqual undefined, modelHello.get('players.2')
                        should.equal    undefined, modelHello.get('players.3')
                        finish()
                  modelFoo:
                    server: (modelFoo, finish) -> finish()
                    browser: (modelFoo, finish) ->
                      modelFoo.set 'players.1.ranking', 4
                      finish()
                , done

              it 'should remove a document that no longer satisfies the query', (done) ->
                fullSetup {store},
                  modelHello:
                    server: (modelHello, finish) ->
                      query = modelHello.query('players').where('ranking').lt(2).limit(2)
                      modelHello.subscribe query, ->
                        should.equal    undefined, modelHello.get('players.1')
                        should.equal    undefined, modelHello.get('players.2')
                        should.notEqual undefined, modelHello.get('players.3')
                        finish()
                    browser: (modelHello, finish) ->
                      modelHello.on 'rmDoc', ->
                        should.equal    undefined, modelHello.get('players.1')
                        should.equal    undefined, modelHello.get('players.2')
                        should.equal    undefined, modelHello.get('players.3')
                        finish()
                  modelFoo:
                    server: (modelFoo, finish) -> finish()
                    browser: (modelFoo, finish) ->
                      modelFoo.set 'players.3.ranking', 2
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
                allPlayers = players + newPlayers
                async.forEach newPlayers
                , (player, callback) ->
                  store.set "players.#{player.id}", player, null, callback
                , ->
                  fullSetup {store},
                    modelHello:
                      server: (modelHello, finish) ->
                        query = modelHello.query('players').where('ranking').lte(5).sort('ranking', 'asc').limit(2).skip(2)
                        modelHello.subscribe query, ->
                          for player in allPlayers
                            if player.ranking not in [3, 4]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                      browser: (modelHello, finish) ->
                        async.forEach ['rmDoc', 'addDoc']
                        , (event, callback) ->
                          modelHello.on event, -> callback()
                        , ->
                          for player in allPlayers
                            if player.ranking not in [4, 5]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                    modelFoo:
                      server: (modelFoo, finish) -> finish()
                      browser: (modelFoo, finish) ->
                        modelFoo.set 'players.1.ranking', 6
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
                allPlayers = players + newPlayers
                async.forEach newPlayers
                , (player, callback) ->
                  store.set "players.#{player.id}", player, null, callback
                , ->
                  fullSetup {store},
                    modelHello:
                      server: (modelHello, finish) ->
                        query = modelHello.query('players').where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
                        modelHello.subscribe query, ->
                          for player in allPlayers
                            if player.ranking not in [3, 4]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                      browser: (modelHello, finish) ->
                        async.forEach ['rmDoc', 'addDoc']
                        , (event, callback) ->
                          modelHello.on event, -> callback()
                        , ->
                          for player in allPlayers
                            if player.ranking not in [4, 5]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                    modelFoo:
                      server: (modelFoo, finish) -> finish()
                      browser: (modelFoo, finish) ->
                        modelFoo.set 'players.1.ranking', 5
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
                allPlayers = players + newPlayers
                async.forEach newPlayers
                , (player, callback) ->
                  store.set "players.#{player.id}", player, null, callback
                , ->
                  fullSetup {store},
                    modelHello:
                      server: (modelHello, finish) ->
                        query = modelHello.query('players').where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
                        modelHello.subscribe query, ->
                          for player in allPlayers
                            if player.ranking not in [3, 4]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                      browser: (modelHello, finish) ->
                        async.forEach ['rmDoc', 'addDoc']
                        , (event, callback) ->
                          modelHello.on event, -> callback()
                        , ->
                          for player in allPlayers
                            if player.ranking not in [4, 5]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                    modelFoo:
                      server: (modelFoo, finish) -> finish()
                      browser: (modelFoo, finish) ->
                        modelFoo.set 'players.1.ranking', 6
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
                allPlayers = players + newPlayers
                async.forEach newPlayers
                , (player, callback) ->
                  store.set "players.#{player.id}", player, null, callback
                , ->
                  fullSetup {store},
                    modelHello:
                      server: (modelHello, finish) ->
                        query = modelHello.query('players').where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
                        modelHello.subscribe query, ->
                          for player in allPlayers
                            if player.ranking not in [3, 4]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                      browser: (modelHello, finish) ->
                        async.forEach ['rmDoc', 'addDoc']
                        , (event, callback) ->
                          modelHello.on event, -> callback()
                        , ->
                          for player in allPlayers
                            if player.ranking not in [2, 3]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                    modelFoo:
                      server: (modelFoo, finish) -> finish()
                      browser: (modelFoo, finish) ->
                        modelFoo.set 'players.6', {id: '6', name: {first: 'Pete', last: 'Sampras'}, ranking: 0}
                        finish()
                  , done

              it 'should move the last member of the prev page to the curr page, if a curr page member mutates in a way that moves it to a prev page', (done) ->
              #   <page prev> <page curr> <page next>
              #       +   <<<<<   -                     unshift to curr from prev
                newPlayers = [
                  {id: '4', name: {first: 'David', last: 'Ferrer'}, ranking: 5}
                  {id: '5', name: {first: 'Andy',  last: 'Murray'}, ranking: 4}
                ]
                allPlayers = players + newPlayers
                async.forEach newPlayers
                , (player, callback) ->
                  store.set "players.#{player.id}", player, null, callback
                , ->
                  fullSetup {store},
                    modelHello:
                      server: (modelHello, finish) ->
                        query = modelHello.query('players').where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
                        modelHello.subscribe query, ->
                          for player in allPlayers
                            if player.ranking not in [3, 4]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                      browser: (modelHello, finish) ->
                        async.forEach ['rmDoc', 'addDoc']
                        , (event, callback) ->
                          modelHello.on event, -> callback()
                        , ->
                          for player in allPlayers
                            if player.ranking not in [2, 3]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                    modelFoo:
                      server: (modelFoo, finish) -> finish()
                      browser: (modelFoo, finish) ->
                        modelFoo.set 'players.5.ranking', 0
                        finish()
                  , done

              it 'should do nothing to the curr page if mutations only add docs to subsequent pages', (done) ->
              #   <page prev> <page curr> <page next>
              #                               +         do nothing to curr
                newPlayers = [
                  {id: '4', name: {first: 'David', last: 'Ferrer'}, ranking: 10}
                  {id: '5', name: {first: 'Andy',  last: 'Murray'}, ranking: 4}
                ]
                allPlayers = players + newPlayers
                async.forEach newPlayers
                , (player, callback) ->
                  store.set "players.#{player.id}", player, null, callback
                , ->
                  fullSetup {store},
                    modelHello:
                      server: (modelHello, finish) ->
                        query = modelHello.query('players').where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
                        modelHello.subscribe query, ->
                          for player in allPlayers
                            if player.ranking not in [3, 4]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                      browser: (modelHello, finish) ->
                        setTimeout ->
                          for player in allPlayers
                            if player.ranking not in [3, 4]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                        , 200
                        modelHello.on 'addDoc', -> finish() # Should never be called
                        modelHello.on 'rmDoc', -> finish() # Should never be called
                    modelFoo:
                      server: (modelFoo, finish) -> finish()
                      browser: (modelFoo, finish) ->
                        modelFoo.set 'players.4.ranking', 5
                        finish()
                  , done

              it 'should do nothing to the curr page if mutations only remove docs from subsequent pages', (done) ->
              #   <page prev> <page curr> <page next>
              #                               -         do nothing to curr
                newPlayers = [
                  {id: '4', name: {first: 'David', last: 'Ferrer'}, ranking: 5}
                  {id: '5', name: {first: 'Andy',  last: 'Murray'}, ranking: 4}
                ]
                allPlayers = players + newPlayers
                async.forEach newPlayers
                , (player, callback) ->
                  store.set "players.#{player.id}", player, null, callback
                , ->
                  fullSetup {store},
                    modelHello:
                      server: (modelHello, finish) ->
                        query = modelHello.query('players').where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
                        modelHello.subscribe query, ->
                          for player in allPlayers
                            if player.ranking not in [3, 4]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                      browser: (modelHello, finish) ->
                        setTimeout ->
                          for player in allPlayers
                            if player.ranking not in [3, 4]
                              should.equal undefined, modelHello.get('players.' + player.id)
                            else
                              modelHello.get('players.' + player.id).should.eql player
                          finish()
                        , 200
                        modelHello.on 'addDoc', -> finish() # Should never be called
                        modelHello.on 'rmDoc', -> finish() # Should never be called
                    modelFoo:
                      server: (modelFoo, finish) -> finish()
                      browser: (modelFoo, finish) ->
                        modelFoo.set 'players.4.ranking', 10
                        finish()
                  , done

              it 'should replace a document (whose recent mutation makes it in-compatible with the query) if another doc in the db is compatible', (done) ->
              #   <page prev> <page curr> <page next>
              #                   -                     push to curr from next
                fullSetup {store},
                  modelHello:
                    server: (modelHello, finish) ->
                      query = modelHello.query('players').where('ranking').lt(5).sort('ranking', 'asc').limit(2)
                      modelHello.subscribe query, ->
                        should.notEqual undefined, modelHello.get('players.1')
                        should.equal    undefined, modelHello.get('players.2')
                        should.notEqual undefined, modelHello.get('players.3')
                        finish()
                    browser: (modelHello, finish) ->
                      async.forEach ['rmDoc', 'addDoc']
                      , (event, callback) ->
                        modelHello.on event, -> callback()
                      , ->
                        should.notEqual undefined, modelHello.get('players.1')
                        should.notEqual undefined, modelHello.get('players.2')
                        should.equal    undefined, modelHello.get('players.3')
                        finish()
                  modelFoo:
                    server: (modelFoo, finish) -> finish()
                    browser: (modelFoo, finish) ->
                      modelFoo.set 'players.3.ranking', 6
                      finish()
                , done

              it 'should replace a document if another doc was just mutated so it supercedes the doc according to the query', (done) ->
                #   <page prev> <page curr> <page next>
                #                   +                     pop from curr to next
                fullSetup {store},
                  modelHello:
                    server: (modelHello, finish) ->
                      query = modelHello.query('players').where('ranking').lt(3).sort('name.first', 'desc').limit(2)
                      modelHello.subscribe query, ->
                        should.notEqual undefined, modelHello.get('players.1')
                        should.equal    undefined, modelHello.get('players.2')
                        should.notEqual undefined, modelHello.get('players.3')
                        finish()
                    browser: (modelHello, finish) ->
                      modelHello.on 'rmDoc', ->
                        should.notEqual undefined, modelHello.get('players.1')
                        should.notEqual undefined, modelHello.get('players.2')
                        should.equal    undefined, modelHello.get('players.3')
                        finish()
                  modelFoo:
                    server: (modelFoo, finish) -> finish()
                    browser: (modelFoo, finish) ->
                      modelFoo.set 'players.2.ranking', 2
                      finish()
                , done

              it 'should keep a document that just re-orders the query result set', (done) ->
              #   <page prev> <page curr> <page next>
              #                   -><-                  re-arrange curr members
                fullSetup {store},
                  modelHello:
                    server: (modelHello, finish) ->
                      query = modelHello.query('players').where('ranking').lt(10).sort('ranking', 'asc').limit(2)
                      modelHello.subscribe query, ->
                        should.notEqual undefined, modelHello.get('players.1')
                        should.equal    undefined, modelHello.get('players.2')
                        should.notEqual undefined, modelHello.get('players.3')
                        finish()
                    browser: (modelHello, finish) ->
                      modelHello.on 'setPost', ->
                        should.notEqual undefined, modelHello.get('players.1')
                        should.equal    undefined, modelHello.get('players.2')
                        should.notEqual undefined, modelHello.get('players.3')
                        modelHello.get('players.1.ranking').should.equal 0
                        finish()
                  modelFoo:
                    server: (modelFoo, finish) -> finish()
                    browser: (modelFoo, finish) ->
                      modelFoo.set 'players.1.ranking', 0
                      finish()
                , done

          describe 'versioning', ->
            players = [
              {id: '1', name: {last: 'Nadal',   first: 'Rafael'}, ranking: 2}
              {id: '2', name: {last: 'Federer', first: 'Roger'},  ranking: 3}
              {id: '3', name: {last: 'Djoker',  first: 'Novak'},  ranking: 1}
            ]
            beforeEach (done) ->
              async.forEach players
              , (player, callback) ->
                store.set "players.#{player.id}", player, null, callback
              , done

            it 'should update the version when the doc is removed from a model because it no longer matches subscriptions', (done) ->
              oldVer = null
              fullSetup {store},
                modelHello:
                  server: (modelHello, finish) ->
                    query = modelHello.query('players').where('ranking').lt(10)
                    modelHello.subscribe query, ->
                      oldVer = modelHello.getVer()
                      finish()
                  browser: (modelHello, finish) ->
                    modelHello.on 'rmDoc', ->
                      modelHello.getVer().should.equal(oldVer + 1)
                      finish()
                modelFoo:
                  server: (modelFoo, finish) -> finish()
                  browser: (modelFoo, finish) ->
                    modelFoo.set 'players.1.ranking', 11
                    finish()
              , done

            it 'should update the version when the doc is added to a model because it starts to matche subscriptions', (done) ->
              oldVer = null
              fullSetup {store},
                modelHello:
                  server: (modelHello, finish) ->
                    query = modelHello.query('players').where('ranking').gt(2)
                    modelHello.subscribe query, ->
                      oldVer = modelHello.getVer()
                      finish()
                  browser: (modelHello, finish) ->
                    modelHello.on 'addDoc', ->
                      modelHello.getVer().should.equal(oldVer + 1)
                      finish()
                modelFoo:
                  server: (modelFoo, finish) -> finish()
                  browser: (modelFoo, finish) ->
                    modelFoo.set 'players.1.ranking', 11
                    finish()
              , done

          describe 'transaction application', ->
            players = [
              {id: '1', name: {last: 'Nadal',   first: 'Rafael'}, ranking: 2}
              {id: '2', name: {last: 'Federer', first: 'Roger'},  ranking: 3}
              {id: '3', name: {last: 'Djoker',  first: 'Novak'},  ranking: 1}
            ]
            beforeEach (done) ->
              async.forEach players
              , (player, callback) ->
                store.set "players.#{player.id}", player, null, callback
              , done

            it 'should apply a txn if a document is still in a query result set after a mutation', (done) ->
              fullSetup {store},
                modelHello:
                  server: (modelHello, finish) ->
                    query = modelHello.query('players').where('ranking').equals(1)
                    modelHello.subscribe query, ->
                      for player in players
                        if player.ranking == 1
                          modelHello.get("players.#{player.id}").should.eql player
                        else
                          should.equal undefined, modelHello.get("players.#{player.id}")
                      finish()
                  browser: (modelHello, finish) ->
                    modelHello.on 'setPost', ->
                      modelHello.get('players.3').should.eql {id: '3', name: {last: 'Djokovic', first: 'Novak'}, ranking: 1}
                      finish()
                modelFoo:
                  server: (modelFoo, finish) -> finish()
                  browser: (modelFoo, finish) ->
                    modelFoo.set 'players.3.name.last', 'Djokovic'
                    finish()
              , done

            it 'should not apply a txn if a document is being added to a query result set after a mutation', (done) ->
              fullSetup {store},
                modelHello:
                  server: (modelHello, finish) ->
                    query = modelHello.query('players').where('name.last').equals('Djokovic')
                    modelHello.subscribe query, ->
                      for player in players
                        should.equal undefined, modelHello.get("players.#{player.id}")
                      finish()
                  browser: (modelHello, finish) ->
                    modelHello.on 'setPost', ([path, val], ver) ->
                      if path == 'players.3'
                        modelHello.get('players.3').should.eql {id: '3', name: {last: 'Djokovic', first: 'Novak'}, ranking: 1}
                        finish()
                      else
                        throw new Error "Should not be setting #{path}"
                modelFoo:
                  server: (modelFoo, finish) -> finish()
                  browser: (modelFoo, finish) ->
                    modelFoo.set 'players.3.name.last', 'Djokovic'
                    finish()
              , done

          describe 'over-subscribing to a doc via 2 queries', ->
            it 'should ignore duplicate transactions'

          describe 'dependent queries', ->
            it "should send updates when they react to their depedency queries' updates"
            it "should not send updates if its dependency queries emit updates that don't impact the dependent query"
