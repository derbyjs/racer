{expect} = require '../util'
racer = require '../../lib/racer'
{mockFullSetup} = require '../util/model'

describe 'Model event patching (lww)', ->

  beforeEach ->
    @store = racer.createStore mode: type: 'lww'

  afterEach (done) ->
    @store.flushMode done

  testBriefOffline = (store, done, {init, mutate, eventual}) ->
    mockFullSetup store, done, [],
      preBundle: (model) ->
        return unless init
        for k, v of init
          model.set k, v
      postConnect: (modelA, modelB, done) ->
        modelA.disconnect()
        mutate modelA, modelB
        modelA.connect()
        process.nextTick ->
          expect(modelA.get()).to.specEql modelB.get()
          for path, expectedVal of eventual
            expect(modelA.get path).to.specEql expectedVal
          done()

  it 'conflicting txn from server should be over-written', (done) ->
    mockFullSetup @store, done, [], (modelA, modelB, done) ->
      modelA.set '_test.name', 'John'
      modelA.disconnect()
      modelB.set '_test.name', 'Sue' # This will be queues on server

      modelA.connect()

      process.nextTick ->
        expect(modelA.get('_test.name')).to.specEql 'John'
        done()

  it 'set on same path', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.set '_test.name', 'John'
        connectedModel.set '_test.name', 'Sue'
      eventual:
        '_test.name': 'Sue'

  it 'set on parent', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.set '_test.user.name', 'John'
        connectedModel.set '_test.user', {}
      eventual:
        '_test.user': {}

  it 'set on child', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.set '_test.user', {}
        connectedModel.set '_test.user.name', 'John'
      eventual:
        '_test.user': {name: 'John'}

  it 'set and del on same path', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.set '_test.user.name', 'John'
        connectedModel.del '_test.user.name'
      eventual:
        '_test.user.name': undefined

  it 'set and push on same path', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.push '_test.items', 'a'
        connectedModel.set '_test.items', []
      eventual:
        '_test.items': []

  it 'pushes on same path', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.push '_test.items', 'a', 'b', 'c'
        disconnectedModel.push '_test.items', 'd'
        connectedModel.push '_test.items', 'x', 'y', 'z'
        connectedModel.push '_test.items', 'm', 'n'
      eventual:
        '_test.items': ['a', 'b', 'c', 'd', 'x', 'y', 'z', 'm', 'n']

  it 'unshifts on same path', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.unshift '_test.items', 'a', 'b', 'c'
        disconnectedModel.unshift '_test.items', 'd'
        connectedModel.unshift '_test.items', 'x', 'y', 'z'
        connectedModel.unshift '_test.items', 'm', 'n'
      eventual:
        '_test.items': ['m', 'n', 'x', 'y', 'z', 'd', 'a', 'b', 'c']

  it 'inserts on same path', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.insert '_test.items', 0, 'a', 'b', 'c'
        disconnectedModel.insert '_test.items', 1, 'd'
        connectedModel.insert '_test.items', 0, 'x', 'y', 'z'
        connectedModel.insert '_test.items', 3, 'm', 'n'
      eventual:
        '_test.items': ['x', 'y', 'z', 'm', 'n', 'a', 'd', 'b', 'c']

  it 'push & pop on same path', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.push '_test.items', 'a', 'b', 'c'
        disconnectedModel.pop '_test.items'
        connectedModel.push '_test.items', 'x'
        connectedModel.pop '_test.items'
      eventual:
        '_test.items': ['a', 'b']

  it 'moves on same path', (done) ->
    testBriefOffline @store, done,
      init:
        '_test.items': [
          {a: 0}
          {b: 1}
          {c: 2}
          {d: 3}
        ]
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.move '_test.items', 0, 3
        connectedModel.move '_test.items', 3, 0
      eventual:
        '_test.items': []

  it 'moves on same path reverse', (done) ->
    testBriefOffline @store, done,
      init:
        '_test.items': [
          {a: 0}
          {b: 1}
          {c: 2}
          {d: 3}
        ]
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.move '_test.items', 3, 0
        connectedModel.move '_test.items', 0, 3
      eventual:
        '_test.items': []

  it 'push, move, & pop on same path', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.push '_test.items', 'a', 'b', 'c'
        disconnectedModel.move '_test.items', 1, 0, 2
        expect(disconnectedModel.get '_test.items').to.specEql ['b', 'c', 'a']
        disconnectedModel.pop '_test.items'
        expect(disconnectedModel.get '_test.items').to.specEql ['b', 'c']
        connectedModel.push '_test.items', 'x', 'y'
        connectedModel.move '_test.items', 0, 1, 1
        expect(connectedModel.get '_test.items').to.specEql ['y', 'x']
        connectedModel.pop '_test.items'
        expect(connectedModel.get '_test.items').to.specEql ['y']

      eventual:
        '_test.items': []

  it 'remove both local and remote', (done) ->
    testBriefOffline @store, done,
      init:
        '_test.items': ['x']
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.remove '_test.items', 0
        connectedModel.remove '_test.items', 0
      eventual:
        '_test.items': []

  it 'push & set on array index remote', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.push '_test.items', 1
        disconnectedModel.set '_test.items.0', 'x'
        connectedModel.push '_test.items', 2
      eventual:
        '_test.items': ['x', 2]

  it 'push & set on array index local', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.push '_test.items', 1
        connectedModel.push '_test.items', 0
        connectedModel.set '_test.items.0', 'x'
      eventual:
        '_test.items': ['x', 0]

  it 'remote set & local push on array child', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.set '_test.items.0.name', 'x'
        connectedModel.push '_test.items', {name: 2}
      eventual:
        '_test.items': [{name: 'x'}, {name: 2}]

  it 'remote push & local set on array child', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.push '_test.items', {name: 2}
        connectedModel.set '_test.items.0.name', 'x'
      eventual:
        '_test.items': [{name: 'x'}]

  it 'remote del & local move on array child', (done) ->
    testBriefOffline @store, done,
      init:
        '_test.items': [1, 2, 3]
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.remove '_test.items', 0
        connectedModel.move '_test.items', 0, 2
      eventual:
        '_test.items': []

  it 'remote push & set on array child', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.push '_test.items', {name: 1}
        disconnectedModel.set '_test.items.0.name', 'x'
        connectedModel.push '_test.items', {name: 2}
      eventual:
        '_test.items': [{name: 'x'}, {name: 2}]

  it 'local push & set on array child', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.push '_test.items', {name: 1}
        connectedModel.push '_test.items', {name: 0}
        connectedModel.set '_test.items.0.name', 'x'
      eventual:
        '_test.items': [{name: 'x'}, {name: 0}]

  it 'local push & nested set on array child', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.push '_test.items', {name: 1}
        connectedModel.push '_test.items', {name: 0}
        connectedModel.set '_test.items.0.stuff.name', 'x'
      eventual:
        '_test.items': [{name: 1, stuff: name: 'x'}, {name: 0}]

  it 'local push & del on array child', (done) ->
    testBriefOffline @store, done,
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.push '_test.items', {name: 1}
        connectedModel.push '_test.items', {name: 0}
        connectedModel.del '_test.items.0.name'
      eventual:
        '_test.items': [{name: 1}, {}]

  it 'local push & nested del on array child', (done) ->
    testBriefOffline @store, done,
      init:
        '_test.items': [{stuff: {name: 2}}]
      mutate: (disconnectedModel, connectedModel) ->
        disconnectedModel.unshift 'items', {name: 1}
        connectedModel.del 'items.0.stuff.name'
      eventual:
        '_test.items': [{name: 1}, {stuff: {}}]
