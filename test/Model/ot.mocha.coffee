{expect} = require '../util'
{mockSocketModel, mockFullSetup, BrowserModel: Model} = require '../util/model'
{run} = require '../util/store'

describe 'Model.ot', ->

  ## Server-side OT ##
  it 'model.ot should initialize the doc version to 0 and the initial value to val if the path is undefined', ->
    model = new Model
    model.ot 'some.ot.path', 'hi'
    expect(model.get 'some.ot.path').to.equal 'hi'
    expect(model.isOtPath 'some.ot.path').to.be.true
    expect(model._otField('some.ot.path').version).to.equal 0

#  'model.subscribe(OTpath) should get the latest OT version doc if
#  the path is specified before-hand as being OT': -> # TODO

  ## Client-side OT ##
  it 'model.otInsert(path, str, pos, callback) should result in a new string with str inserted at pos', ->
    model = new Model
    model.socket = emit: -> # Stub
    model.ot 'some.ot.path', ''
    model.otInsert 'some.ot.path', 0, 'abcdef'
    expect(model.get 'some.ot.path').to.equal 'abcdef'
    out = model.otInsert 'some.ot.path', 1, 'xyz'
    expect(out).to.equal undefined
    expect(model.get 'some.ot.path').to.equal 'axyzbcdef'

  it 'model.otDel(path, len, pos, callback) should result in a new string with str removed at pos', ->
    model = new Model
    model.socket = emit: -> # Stub
    model.ot 'some.ot.path', 'abcdef'
    out = model.otDel 'some.ot.path', 1, 3
    expect(out).to.eql 'bcd'
    expect(model.get 'some.ot.path').to.equal 'aef'

  it 'model should emit an otInsert event when it calls model.otInsert locally', (done) ->
    model = new Model
    model.socket = emit: -> # Stub
    model.ot 'some.ot.path', 'abcdef'
    model.on 'otInsert', 'some.ot.path', (pos, insertedStr) ->
      expect(insertedStr).to.equal 'xyz'
      expect(pos).to.equal 1
      done()
    model.otInsert 'some.ot.path', 1, 'xyz'

  it 'model should emit a otDel event when it calls model.otDel locally', (done) ->
    model = new Model
    model.socket = emit: -> # Stub
    model.ot 'some.ot.path', 'abcdef'
    model.on 'otDel', 'some.ot.path', (pos, deletedStr) ->
      expect(deletedStr).to.equal 'bcd'
      expect(pos).to.equal 1
      done()
    model.otDel 'some.ot.path', 1, 3

  # Client-server OT communication ##
  it 'client model should emit an otInsert event when it receives an OT message from the server with an otInsert op', (done) ->
    [model, sockets] = mockSocketModel '0'
    model.ot 'some.ot.path', 'abcdef'
    model.on 'otInsert', 'some.ot.path', (pos, insertedStr) ->
      expect(insertedStr).to.equal 'try'
      expect(pos).to.equal 1
      sockets._disconnect()
      done()
    sockets.emit 'otOp', path: 'some.ot.path', op: [{i: 'try', p: 1}], v: 1

  it 'client model should emit a otDel event when it receives an OT message from the server with an otDel op', (done) ->
    [model, sockets] = mockSocketModel '0'
    model.ot 'some.ot.path', 'abcdef'
    model.on 'otDel', 'some.ot.path', (pos, strToDel) ->
      expect(strToDel).to.equal 'bcd'
      expect(pos).to.equal 1
      sockets._disconnect()
      done()
    sockets.emit 'otOp', path: 'some.ot.path', op: [{d: 'bcd', p: 1}], v: 1


run 'Model.ot connected to a store', (getStore) ->

  it 'otInsert events should be emitted in remote subscribed models',
    mockFullSetup getStore, numBrowsers: 2, (modelA, modelB, done) ->
      modelB.on 'otInsert', '_test.text', (pos, insertedStr) ->
        expect(insertedStr).to.equal 'xyz'
        expect(pos).to.equal 1
        expect(modelB.get '_test.text').to.equal 'axyzbcdef'
        done()
      modelA.ot '_test.text', 'abcdef'
      modelA.otInsert '_test.text', 1, 'xyz'

  ## Validity ##
  it '1 otInsert by window A and 1 otInsert by window B on the same path should result in the same "valid" text in both windows after both ops have propagated, transformed, and applied both ops', (done) ->
    numModels = 2
    fullyWiredModels numModels, (sockets, store, modelA, modelB) ->
      modelB.on 'set', '_test.text', ->
        modelB.otInsert '_test.text', 2, 'tuv'
      modelA.ot '_test.text', 'abcdef'

      models = [modelA, modelB]
      models.forEach (model, i) ->
        otherModel = models[i+1] || models[i-1]
        model.__events__ = 0
        model._on 'otInsert', ([path, pos, insertedStr], isRemote) ->
          return unless path == '_test.text'
          return if ++model.__events__ < 2
          model.__final__ = model.get '_test.text'
          if model.__events__ == otherModel.__events__
            expect(model.__final__).to.equal otherModel.__final__
            sockets._disconnect()
            store.disconnect()
            done()
      modelA.otInsert '_test.text', 1, 'xyz'

  it '1 otInsert by window A and 1 otDel by window B on the same path should result in the same "valid" text in both windows after both ops have propagated, transformed, and applied both ops', (done) ->
    numModels = 2
    fullyWiredModels numModels, (sockets, store, modelA, modelB) ->
      modelB.on 'set', '_test.text', ->
        modelB.otInsert '_test.text', 2, 'tuv'
      modelA.ot '_test.text', 'abcdef'

      modelA.otDel '_test.text', 1, 3
      setTimeout ->
        expect(modelB.get '_test.text').to.equal modelA.get('_test.text')
        sockets._disconnect()
        store.disconnect()
        done()
      , 50

  it '1 otDel by window A and 1 otDel by window B on the same path should result in the same "valid" text in both windows after both ops have propagated, transformed, and applied both ops', (done) ->
    numModels = 2
    fullyWiredModels numModels, (sockets, store, modelA, modelB) ->
      modelB.on 'set', '_test.text', ->
        modelB.otDel '_test.text', 2, 3
      modelA.ot '_test.text', 'abcdefghijk'
      modelA.otDel '_test.text', 1, 3
      setTimeout ->
        expect(modelB.get '_test.text').to.equal modelA.get('_test.text')
        sockets._disconnect()
        store.disconnect()
        done()
      , 50

  it 'an OT op in window A should be reflected in the data of a window Bs server model that loads after window A and its OT op', (done) ->
    fullyWiredModels 2, (sockets, store, modelA, modelC) ->

      createModelB = ->
        modelB = store.createModel()
        path = modelC.dereference('_test')
        modelB.subscribe path, ->
          modelB.ref '_test', path
          expect(modelB.get '_test.text').to.equal 'axyzbcdefg'
          sockets._disconnect()
          store.disconnect()
          done()

      didInsert = false
      didSet = false
      modelC.on 'set', '_test.text', ->
        didSet = true
        createModelB() if didInsert
      modelC.on 'otInsert', '_test.text', ->
        didInsert = true
        createModelB() if didSet
      modelA.ot '_test.text', 'abcdefg'
      modelA.otInsert '_test.text', 1, 'xyz'

  it 'an OT op in window A should be reflected in the data of a window Bs browser model that loads after window A and its OT op', (done) ->
    fullyWiredModels 2, (sockets, store, modelA, modelC) ->

      createModelB = ->
        serverModelB = store.createModel()
        path = modelC.dereference('_test')
        serverModelB.subscribe path, ->
          serverModelB.ref '_test', path
          serverModelB.bundle (bundle) ->
            bundle = JSON.parse bundle
            bundle.socket = new BrowserSocketMock sockets
            browserModelB = new Model
            browserRacer.init.call model: browserModelB, bundle
            expect(browserModelB.get '_test.text').to.equal 'axyzbcdefg'

            sockets._disconnect()
            store.disconnect()
            done()

      didInsert = false
      didSet = false
      modelC.on 'set', '_test.text', ->
        didSet = true
        createModelB() if didInsert
      modelC.on 'otInsert', '_test.text', ->
        didInsert = true
        createModelB() if didSet
      modelA.ot '_test.text', 'abcdefg'
      modelA.otInsert '_test.text', 1, 'xyz'


 # TODO ## Realtime mode conflicts (w/STM) ##

 # TODO Speculative workspaces with immediate OT
