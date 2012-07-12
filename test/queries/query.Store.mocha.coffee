{expect} = require '../util'
racer = require '../../lib/racer'
QueryBuilder = require '../../lib/queries/QueryBuilder'

describe 'store.query.expose', ->
  describe 'query builder action inside callback', ->
    describe 'coffee-style vs JS-style signatures', ->
      it 'should return equivalent queries', ->
        store = racer.createStore()

        store.query.expose 'users', 'jsQuery', ->
          @where('name').equals('brian').where('age').equals(26)

        store.query.expose 'users', 'csQuery', ->
          @query
            where:
              name: 'brian'
              age: 26

#        store.query.expose 'users', 'csQuery',
#          where:
#            name: (name) -> name
#            age: 26

        store.query.expose 'users', 'jsQueryComplex', ->
          @where('name').equals('Gnarls')
            .where('gender').notEquals('female')
            .where('age').gt(21).lte(30)
            .where('numFriends').gte(100).lt(200)
            .where('tags').contains(['super', 'derby'])
            .where('shoe').within(['nike', 'adidas'])
            .skip(10).limit(5)

        store.query.expose 'users', 'csQueryComplex', ->
          @query
            where:
              name:
                equals: 'Gnarls'
              gender:
                notEquals: 'female'
              age:
                gt: 21
                lte: 30
              numFriends:
                gte: 100
                lt: 200
              tags:
                contains: ['super', 'derby']
              shoe:
                within: ['nike', 'adidas']
            skip: 10
            limit: 5

        store.query.expose 'users', 'jsIdOne', ->
          @byId('1')

        store.query.expose 'users', 'csIdOne', ->
          @query byId: '1'

        model = store.createModel()

        registry = store._queryMotifRegistry
        [
          ['jsQuery', 'csQuery']
        , ['jsQueryComplex', 'csQueryComplex']
        , ['jsIdOne', 'csIdOne']].forEach ([jsQ, csQ]) ->
          jsQuery = model.query('users')[jsQ]()
          csQuery = model.query('users')[csQ]()

          jsJson = registry.queryJSON(jsQuery)
          csJson = registry.queryJSON(jsQuery)

          expect(jsJson).to.eql csJson

    it 'should support nested attribute queries', (done) ->
      store = racer.createStore()

      store.query.expose 'users', 'withFirstName', (fname) ->
        @where('name.first').equals(fname)

      store.set 'users.1', {
        id:  '1'
        name:
          first: 'Brian'
          last: 'N'
      }, null, (err) ->
        expect(err).to.be.null()

        model = store.createModel()
        query = model.query('users').withFirstName('Brian')
        model.fetch query, (err, brians) ->
          expect(err).to.be.null()
          expect(brians.get()).to.eql [
            {
              id: '1'
              name:
                first: 'Brian'
                last: 'N'
            }
          ]
          done()

    it 'can retrieve queries built with Store#query with Store#fetch', (done) ->
      store = racer.createStore()

      store.query.expose 'users', 'withFirstName', (fname) ->
        @where('name.first').equals(fname).one()

      store.set 'users.1', {
        id:  '1'
        name:
          first: 'Brian'
          last: 'N'
      }, null, (err) ->
        expect(err).to.be.null()

        query = store.query('users').withFirstName('Brian')
        store.fetch query, (err, brian) ->
          expect(err).to.be.null()
          expect(brian).to.eql
            id: '1'
            name:
              first: 'Brian'
              last: 'N'
          done()
