should = require 'should'
Store = require '../src/Store'
redis = require 'redis'
async = require 'async'
{calls} = require './util'
{fullSetup} = require './util/model'

describe 'Live Querying', ->
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
                postCondition: (subscriberBrowserModel, finish) ->
                  subscriberBrowserModel.get('users.1').should.eql {id: '1', greeting: 'hello', age: 21}
                  subscriberBrowserModel.on 'rmDoc', ->
                    # This should never get called. Keep it here to detect if we call > 1
                    throw new Error 'Should not rmDoc'
                mutate: (publisherBrowserModel) ->
                  publisherBrowserModel.set 'users.1.greeting', 'hello'

              # TODO Re-visit this because we should propagate the txn, not replace
              #      via addDoc
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
                  subscriberBrowserModel.on 'addDoc', onMutation
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

          describe 'incr', ->

          describe 'push', ->

          describe 'unshift', ->

          describe 'insert', ->

          describe 'pop', ->

          describe 'shift', ->

          describe 'remove', ->

          describe 'move', ->
