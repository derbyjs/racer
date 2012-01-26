should = require 'should'
Store = require '../src/Store'
redis = require 'redis'
async = require 'async'
{calls} = require './util'

describe 'Live Querying', ->

  store = null

  describe 'with Mongo', ->

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
            numModels = 2
            # TODO LIVE_QUERY
            fullSetup numModels
            , (sockets, modelHello, modelFoo) ->
                queryHello = modelHello.query('users').where('greeting').equals('hello')
                modelFoo.set 'users.1', user = id: 1, greeting: 'foo'
                modelHello.subscribe queryHello, ->
                  should.equal undefined, modelHello.get 'users.1'
            , (modelHello) ->
                modelHello.on 'changeDataSet', ->
                  modelHello.get('users.1').should.eql user
                  done()
            , (modelFoo) ->
                modelFoo.set 'users.1.greeting', 'hello'

            # TODO Remove the below code once the above code is done
            modelHello = store.createModel()
            queryHello = modelHello.query('users').where('greeting').equals('hello')

            modelFoo = store.createModel()
            modelFoo.set 'users.1', user = id: 1, greeting: 'foo'

            modelHello.subscribe queryHello, ->
              should.equal undefined, modelHello.get 'users.1'
              modelHello.on 'changeDataSet', ->
                modelHello.get('users.1').should.eql user
                done()
              modelFoo.set 'users.1.greeting', 'hello'

          it 'should remove the modified doc from any models subscribed to a query matching the doc pre-mutation but not matching the doc post-mutation'

          it 'should keep the modified doc in any models subscribed to (1) a query matching the doc pre-mutation but not matching the doc post-mutation '+
             'and (2) a query matching the doc both pre- and post-mutation'

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
