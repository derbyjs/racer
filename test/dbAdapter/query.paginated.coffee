{expect} = require '../util'
{forEach} = require '../../src/util'
{mockFullSetup} = require '../util/model'

module.exports = (getStore, getCurrNs) ->
  store = currNs = null
  players = [
    {id: '1', name: {last: 'Nadal',   first: 'Rafael'}, ranking: 2}
    {id: '2', name: {last: 'Federer', first: 'Roger'},  ranking: 3}
    {id: '3', name: {last: 'Djoker',  first: 'Novak'},  ranking: 1}
  ]

  beforeEach (done) ->
    store = getStore()
    currNs = getCurrNs()
    forEach players, (player, callback) ->
      store.set "#{currNs}.#{player.id}", player, null, callback
    , done

  describe 'for non-saturated result sets (e.g., limit=10, sizeof(resultSet) < 10)', ->
    it 'should add a document that satisfies the query',
      mockFullSetup getStore, {numBrowsers: 2}, (modelA, modelB, done) ->
        modelA.on 'addDoc', ->
          expect(modelA.get "#{currNs}.1").to.not.equal undefined
          expect(modelA.get "#{currNs}.2").to.not.equal undefined
          expect(modelA.get "#{currNs}.3").to.equal undefined
          done()
        query = modelA.query(currNs).where('ranking').gte(3).limit(2)
        modelA.subscribe query, ->
          expect(modelA.get "#{currNs}.1").to.equal undefined
          expect(modelA.get "#{currNs}.2").to.not.equal undefined
          expect(modelA.get "#{currNs}.3").to.equal undefined
          modelB.set "#{currNs}.1.ranking", 4

    it 'should remove a document that no longer satisfies the query',
      mockFullSetup getStore, {numBrowsers: 2}, (modelA, modelB, done) ->
        modelA.on 'rmDoc', ->
          expect(modelA.get "#{currNs}.1").to.equal undefined
          expect(modelA.get "#{currNs}.2").to.equal undefined
          expect(modelA.get "#{currNs}.3").to.equal undefined
          done()
        query = modelA.query(currNs).where('ranking').lt(2).limit(2)
        modelA.subscribe query, ->
          expect(modelA.get "#{currNs}.1").to.equal undefined
          expect(modelA.get "#{currNs}.2").to.equal undefined
          expect(modelA.get "#{currNs}.3").to.not.equal undefined
          modelB.set "#{currNs}.3.ranking", 2

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
          modelA:
            server: (modelA, finish) ->
              query = modelA.query(currNs).where('ranking').lte(5).sort('ranking', 'asc').limit(2).skip(2)
              modelA.subscribe query, ->
                for player in allPlayers
                  if player.ranking not in [3, 4]
                    expect(modelA.get "#{currNs}." + player.id).to.equal undefined
                  else
                    expect(modelA.get "#{currNs}." + player.id).to.eql player
                finish()
            browser: (modelA, finish) ->
              forEach ['rmDoc', 'addDoc'], (event, callback) ->
                modelA.on event, -> callback()
              , ->
                modelPlayers = modelA.get currNs
                for _, player of modelPlayers
                  expect(player.ranking).to.be.within 4, 5
                finish()
          modelB:
            server: (modelB, finish) -> finish()
            browser: (modelB, finish) ->
              modelB.set "#{currNs}.1.ranking", 6
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
          modelA:
            server: (modelA, finish) ->
              query = modelA.query(currNs).where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
              modelA.subscribe query, ->
                for player in allPlayers
                  if player.ranking not in [3, 4]
                    expect(modelA.get "#{currNs}." + player.id).to.equal undefined
                  else
                    expect(modelA.get "#{currNs}." + player.id).to.eql player
                finish()
            browser: (modelA, finish) ->
              forEach ['rmDoc', 'addDoc'], (event, callback) ->
                modelA.on event, ->
                  callback()
              , ->
                modelPlayers = modelA.get currNs
                for _, player of modelPlayers
                  expect(player.ranking).to.be.within 4, 5
                finish()
          modelB:
            server: (modelB, finish) -> finish()
            browser: (modelB, finish) ->
              modelB.set "#{currNs}.1.ranking", 5
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
          modelA:
            server: (modelA, finish) ->
              query = modelA.query(currNs).where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
              modelA.subscribe query, ->
                for player in allPlayers
                  if player.ranking not in [3, 4]
                    expect(modelA.get "#{currNs}." + player.id).to.equal undefined
                  else
                    expect(modelA.get "#{currNs}." + player.id).to.eql player
                finish()
            browser: (modelA, finish) ->
              forEach ['rmDoc', 'addDoc'], (event, callback) ->
                modelA.on event, -> callback()
              , ->
                modelPlayers = modelA.get currNs
                for _, player of modelPlayers
                  expect(player.ranking).to.be.within 4, 5
                finish()
          modelB:
            server: (modelB, finish) -> finish()
            browser: (modelB, finish) ->
              modelB.set "#{currNs}.1.ranking", 6
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
          modelA:
            server: (modelA, finish) ->
              query = modelA.query(currNs).where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
              modelA.subscribe query, ->
                for player in allPlayers
                  if player.ranking not in [3, 4]
                    expect(modelA.get "#{currNs}." + player.id).to.equal undefined
                  else
                    expect(modelA.get "#{currNs}." + player.id).to.eql player
                finish()
            browser: (modelA, finish) ->
              forEach ['rmDoc', 'addDoc'], (event, callback) ->
                modelA.on event, -> callback()
              , ->
                modelPlayers = modelA.get currNs
                for _, player of modelPlayers
                  expect(player.ranking).to.be.within 2, 3
                finish()
          modelB:
            server: (modelB, finish) -> finish()
            browser: (modelB, finish) ->
              modelB.set "#{currNs}.6", {id: '6', name: {first: 'Pete', last: 'Sampras'}, ranking: 0}
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
          modelA:
            server: (modelA, finish) ->
              query = modelA.query(currNs).where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
              modelA.subscribe query, ->
                for player in allPlayers
                  if player.ranking not in [3, 4]
                    expect(modelA.get "#{currNs}." + player.id).to.equal undefined
                  else
                    expect(modelA.get "#{currNs}." + player.id).to.eql player
                finish()
            browser: (modelA, finish) ->
              forEach ['rmDoc', 'addDoc'], (event, callback) ->
                modelA.on event, -> callback()
              , ->
                modelPlayers = modelA.get currNs
                for _, player of modelPlayers
                  expect(player.ranking).to.be.within 2, 3
                finish()
          modelB:
            server: (modelB, finish) -> finish()
            browser: (modelB, finish) ->
              modelB.set "#{currNs}.5.ranking", 0
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
          modelA:
            server: (modelA, finish) ->
              query = modelA.query(currNs).where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
              modelA.subscribe query, ->
                for player in allPlayers
                  if player.ranking not in [3, 4]
                    expect(modelA.get "#{currNs}." + player.id).to.equal undefined
                  else
                    expect(modelA.get "#{currNs}." + player.id).to.eql player
                finish()
            browser: (modelA, finish) ->
              setTimeout ->
                for player in allPlayers
                  if player.ranking not in [3, 4]
                    expect(modelA.get "#{currNs}." + player.id).to.equal undefined
                  else
                    expect(modelA.get "#{currNs}." + player.id).to.eql player
                finish()
              , 200
              modelA.on 'addDoc', -> finish() # Should never be called
              modelA.on 'rmDoc', -> finish() # Should never be called
          modelB:
            server: (modelB, finish) -> finish()
            browser: (modelB, finish) ->
              modelB.set "#{currNs}.4.ranking", 5
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
          modelA:
            server: (modelA, finish) ->
              query = modelA.query(currNs).where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
              modelA.subscribe query, ->
                for player in allPlayers
                  if player.ranking not in [3, 4]
                    expect(modelA.get "#{currNs}." + player.id).to.equal undefined
                  else
                    expect(modelA.get "#{currNs}." + player.id).to.eql player
                finish()
            browser: (modelA, finish) ->
              setTimeout ->
                modelPlayers = modelA.get currNs
                for _, player of modelPlayers
                  expect(player.ranking).to.be.within 3, 4
                finish()
              , 200
              modelA.on 'addDoc', -> finish() # Should never be called
              modelA.on 'rmDoc', -> finish() # Should never be called
          modelB:
            server: (modelB, finish) -> finish()
            browser: (modelB, finish) ->
              modelB.set "#{currNs}.4.ranking", 10
              finish()
        , done

    it 'should replace a document (whose recent mutation makes it in-compatible with the query) if another doc in the db is compatible', (done) ->
    #   <page prev> <page curr> <page next>
    #                   -                     push to curr from next
      fullSetup {store},
        modelA:
          server: (modelA, finish) ->
            query = modelA.query(currNs).where('ranking').lt(5).sort('ranking', 'asc').limit(2)
            modelA.subscribe query, ->
              expect(modelA.get "#{currNs}.1").to.not.equal undefined
              expect(modelA.get "#{currNs}.2").to.equal undefined
              expect(modelA.get "#{currNs}.3").to.not.equal undefined
              finish()
          browser: (modelA, finish) ->
            forEach ['rmDoc', 'addDoc'], (event, callback) ->
              modelA.on event, -> callback()
            , ->
              expect(modelA.get "#{currNs}.1").to.not.equal undefined
              expect(modelA.get "#{currNs}.2").to.not.equal undefined
              expect(modelA.get "#{currNs}.3").to.equal undefined
              finish()
        modelB:
          server: (modelB, finish) -> finish()
          browser: (modelB, finish) ->
            modelB.set "#{currNs}.3.ranking", 6
            finish()
      , done

    it 'should replace a document if another doc was just mutated so it supercedes the doc according to the query', (done) ->
      #   <page prev> <page curr> <page next>
      #                   +                     pop from curr to next
      fullSetup {store},
        modelA:
          server: (modelA, finish) ->
            query = modelA.query(currNs).where('ranking').lt(3).sort('name.first', 'desc').limit(2)
            modelA.subscribe query, ->
              expect(modelA.get "#{currNs}.1").to.not.equal undefined
              expect(modelA.get "#{currNs}.2").to.equal undefined
              expect(modelA.get "#{currNs}.3").to.not.equal undefined
              finish()
          browser: (modelA, finish) ->
            modelA.on 'rmDoc', ->
              expect(modelA.get "#{currNs}.1").to.not.equal undefined
              expect(modelA.get "#{currNs}.2").to.not.equal undefined
              expect(modelA.get "#{currNs}.3").to.equal undefined
              finish()
        modelB:
          server: (modelB, finish) -> finish()
          browser: (modelB, finish) ->
            modelB.set "#{currNs}.2.ranking", 2
            finish()
      , done

    it 'should keep a document that just re-orders the query result set', (done) ->
    #   <page prev> <page curr> <page next>
    #                   -><-                  re-arrange curr members
      fullSetup {store},
        modelA:
          server: (modelA, finish) ->
            query = modelA.query(currNs).where('ranking').lt(10).sort('ranking', 'asc').limit(2)
            modelA.subscribe query, ->
              expect(modelA.get "#{currNs}.1").to.not.equal undefined
              expect(modelA.get "#{currNs}.2").to.equal undefined
              expect(modelA.get "#{currNs}.3").to.not.equal undefined
              finish()
          browser: (modelA, finish) ->
            modelA.on 'setPost', ->
              expect(modelA.get "#{currNs}.1").to.not.equal undefined
              expect(modelA.get "#{currNs}.2").to.equal undefined
              expect(modelA.get "#{currNs}.3").to.not.equal undefined
              expect(modelA.get "#{currNs}.1.ranking").to.equal 0
              finish()
        modelB:
          server: (modelB, finish) -> finish()
          browser: (modelB, finish) ->
            modelB.set "#{currNs}.1.ranking", 0
            finish()
      , done
