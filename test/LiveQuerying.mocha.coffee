should = require 'should'
Store = require '../src/Store'
redis = require 'redis'
async = require 'async'
{calls} = require './util'
{fullSetup} = require './util/model'

describe 'Live Querying', ->
  describe 'with Mongo', ->
    store = null

    beforeEach ->
      MongoAdapter = require '../src/adapters/Mongo'
      mongo = new MongoAdapter 'mongodb://localhost/database'
      mongo.connect()
      # Can't make this a `before` callback because redis pub/sub
      # may bleed from one test into the next
      store = new Store
        adapter: mongo
        stm: false

    afterEach (done) ->
      store.flush ->
        # TODO Hide these end() calls behind a better
        #      method abstraction
        store._redisClient.end()
        store._subClient.end()
        store._txnSubClient.end()
        done()

    describe 'subscribe fetches', ->
      users = [
        { id: '0', name: 'brian', age: 25, workdays: ['mon', 'tue', 'wed'] }
        { id: '1', name: 'nate' , age: 26, workdays: ['mon', 'wed', 'fri'] }
        { id: '2', name: 'x'    , age: 27, workdays: ['mon', 'thu', 'fri'] }
      ]

      beforeEach (done) ->
        ver = 0
        async.forEach users
        , (user, callback) ->
          store.set "users.#{user.id}", user, ++ver, callback
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

      describe 'set <namespace>.<id>.*', ->
        describe 'for equals queries', ->
          it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation', (done) ->
            fullSetup {store},
              modelHello:
                server: (modelHello, finish) ->
                  queryHello = modelHello.query('users').where('greeting').equals('hello')
                  modelHello.subscribe queryHello, ->
                    should.equal undefined, modelHello.get 'users.1'
                    finish()
                browser: (modelHello, finish) ->
                  modelHello.on 'addDoc', ->
                    modelHello.get('users.1').should.eql {id: '1', greeting: 'hello'}
                    finish()
              modelFoo:
                server: (modelFoo, finish) ->
                  modelFoo.set 'users.1', user = id: '1', greeting: 'foo'
                  finish()
                browser: (modelFoo, finish) ->
                  modelFoo.set 'users.1.greeting', 'hello'
                  finish()
            , done

          it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation', (done) ->
            fullSetup {store},
              modelHello:
                server: (modelHello, finish) ->
                  queryHello = modelHello.query('users').where('greeting').equals('foo')
                  modelHello.subscribe queryHello, ->
                    finish()
                browser: (modelHello, finish) ->
                  modelHello.on 'setPost', ->
                    modelHello.get('users.1').should.eql {id: '1', greeting: 'foo'}
                    modelHello.on 'rmDoc', ->
                      should.equal undefined, modelHello.get 'users.1'
                      finish()
              modelFoo:
                server: (modelFoo, finish) ->
                  modelFoo.set 'users.1', user = id: '1', greeting: 'foo'
                  finish()
                browser: (modelFoo, finish) ->
                  modelFoo.set 'users.1.greeting', 'hello'
                  finish()
            , done

          it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
             'and (2) a query matching the doc both pre- and post-mutation', (done) ->
            fullSetup {store},
              modelHello:
                server: (modelHello, finish) ->
                  queryUno = modelHello.query('users').where('greeting').equals('foo')
                  queryDos = modelHello.query('users').where('age').equals(21)
                  modelHello.subscribe queryUno, queryDos, ->
                    finish()
                browser: (modelHello, finish) ->
                  modelHello.on 'setPost', ([path, val]) ->
                    if path == 'users.1.greeting' && val == 'hello'
                      modelHello.get('users.1').should.eql {id: '1', greeting: 'hello', age: 21}
                      finish()
                      modelHello.on 'rmDoc', ->
                        finish() # This should never get called. Keep it here to detect if we call > 1
              modelFoo:
                server: (modelFoo, finish) ->
                  modelFoo.set 'users.1', user = id: '1', greeting: 'foo', age: 21
                  finish()
                browser: (modelFoo, finish) ->
                  modelFoo.set 'users.1.greeting', 'hello'
                  finish()
            , done

          it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
             ' and (2) a query not matching the doc pre-mutation but matching the doc post-mutation'

        describe 'for gt/gte/lt/lte queries', ->
          it 'should add the modified doc to any models subscribed to a query not matching the doc pre-mutation but matching the doc post-mutation'

          it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation'

      describe 'del <namespace>.<id>', ->
        it 'should remove the modified doc from any models subscribed to a query matching the doc pre-del'

      describe 'del <namespace>.<id>.*', ->
        it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation'

      describe 'incr', ->

      describe 'push', ->

      describe 'unshift', ->

      describe 'insert', ->

      describe 'pop', ->

      describe 'shift', ->

      describe 'remove', ->

      describe 'move', ->

  describe 'with Memory', ->
