{expect} = require './util'
{Model} = require '../src/racer'
{mockSocketModel, fullyWiredModels} = require './util/model'
{BrowserSocketMock} = require './util/sockets'

Model::_commit = ->

describe 'Model.ot', ->

  ## Server-side OT ##
  it 'model.set(path, model.ot(val)) should initialize the doc version to 0 and the initial value to val if the path is undefined', ->
    model = new Model
    model.set 'some.ot.path', model.ot('hi')
    expect(model.get 'some.ot.path').to.equal 'hi'
    expect(model.isOtPath 'some.ot.path').to.be.true
    expect(model._otField('some.ot.path').version).to.equal 0

#  'model.subscribe(OTpath) should get the latest OT version doc if
#  the path is specified before-hand as being OT': -> # TODO

  ## Client-side OT ##
  it 'model.insertOT(path, str, pos, callback) should result in a new string with str inserted at pos', ->
    model = new Model
    model.socket = emit: -> # Stub
    model.set 'some.ot.path', model.ot()
    model.insertOT 'some.ot.path', 0, 'abcdef'
    expect(model.get 'some.ot.path').to.equal 'abcdef'
    out = model.insertOT 'some.ot.path', 1, 'xyz'
    expect(out).to.equal undefined
    expect(model.get 'some.ot.path').to.equal 'axyzbcdef'

  it 'model.delOT(path, len, pos, callback) should result in a new string with str removed at pos', ->
    model = new Model
    model.socket = emit: -> # Stub
    model.set 'some.ot.path', model.ot('abcdef')
    out = model.delOT 'some.ot.path', 1, 3
    expect(out).to.eql 'bcd'
    expect(model.get 'some.ot.path').to.equal 'aef'

  it 'model should emit an insertOT event when it calls model.insertOT locally', (done) ->
    model = new Model
    model.socket = emit: -> # Stub
    model.set 'some.ot.path', model.ot('abcdef')
    model.on 'insertOT', 'some.ot.path', (pos, insertedStr) ->
      expect(insertedStr).to.equal 'xyz'
      expect(pos).to.equal 1
      done()
    model.insertOT 'some.ot.path', 1, 'xyz'

  it 'model should emit a delOT event when it calls model.delOT locally', (done) ->
    model = new Model
    model.socket = emit: -> # Stub
    model.set 'some.ot.path', model.ot('abcdef')
    model.on 'delOT', 'some.ot.path', (pos, deletedStr) ->
      expect(deletedStr).to.equal 'bcd'
      expect(pos).to.equal 1
      done()
    model.delOT 'some.ot.path', 1, 3

  ## Client-server OT communication ##
  it 'client model should emit an insertOT event when it receives an OT message from the server with an insertOT op', (done) ->
    [model, sockets] = mockSocketModel '0'
    model.set 'some.ot.path', model.ot('abcdef')
    model.on 'insertOT', 'some.ot.path', (pos, insertedStr) ->
      expect(insertedStr).to.equal 'try'
      expect(pos).to.equal 1
      sockets._disconnect()
      done()
    sockets.emit 'otOp', path: 'some.ot.path', op: [{i: 'try', p: 1}], v: 1

  it 'client model should emit a delOT event when it receives an OT message from the server with an delOT op', (done) ->
    [model, sockets] = mockSocketModel '0'
    model.set 'some.ot.path', model.ot('abcdef')
    model.on 'delOT', 'some.ot.path', (pos, strToDel) ->
      expect(strToDel).to.equal 'bcd'
      expect(pos).to.equal 1
      sockets._disconnect()
      done()
    sockets.emit 'otOp', path: 'some.ot.path', op: [{d: 'bcd', p: 1}], v: 1

  it 'local client model insertOTs should result in the same text in sibling windows', (done) ->
    numModels = 2
    fullyWiredModels numModels, (sockets, store, modelA, modelB) ->
      modelA.set '_test.text', modelA.ot('abcdef')
      modelB.on 'insertOT', '_test.text', (pos, insertedStr) ->
        expect(insertedStr).to.equal 'xyz'
        expect(pos).to.equal 1
        expect(modelB.get '_test.text').to.equal 'axyzbcdef'
        sockets._disconnect()
        store.disconnect()
        done()
      modelA.insertOT '_test.text', 1, 'xyz'

  ## Validity ##
  it '1 insertOT by window A and 1 insertOT by window B on the same path should result in the same "valid" text in both windows after both ops have propagated, transformed, and applied both ops', (done) ->
    numModels = 2
    fullyWiredModels numModels, (sockets, store, modelA, modelB) ->
      modelB.on 'set', '_test.text', ->
        modelB.insertOT '_test.text', 2, 'tuv'
      modelA.set '_test.text', modelA.ot('abcdef')

      models = [modelA, modelB]
      models.forEach (model, i) ->
        otherModel = models[i+1] || models[i-1]
        model.__events__ = 0
        model._on 'insertOT', ([path, pos, insertedStr], isRemote) ->
          return unless path == '_test.text'
          return if ++model.__events__ < 2
          model.__final__ = model.get '_test.text'
          if model.__events__ == otherModel.__events__
            expect(model.__final__).to.equal otherModel.__final__
            sockets._disconnect()
            store.disconnect()
            done()
      modelA.insertOT '_test.text', 1, 'xyz'

  it '1 insertOT by window A and 1 delOT by window B on the same path should result in the same "valid" text in both windows after both ops have propagated, transformed, and applied both ops', (done) ->
    numModels = 2
    fullyWiredModels numModels, (sockets, store, modelA, modelB) ->
      modelB.on 'set', '_test.text', ->
        modelB.insertOT '_test.text', 2, 'tuv'
      modelA.set '_test.text', modelA.ot('abcdef')

      modelA.delOT '_test.text', 1, 3
      setTimeout ->
        expect(modelB.get '_test.text').to.equal modelA.get('_test.text')
        sockets._disconnect()
        store.disconnect()
        done()
      , 50

  it '1 delOT by window A and 1 delOT by window B on the same path should result in the same "valid" text in both windows after both ops have propagated, transformed, and applied both ops', (done) ->
    numModels = 2
    fullyWiredModels numModels, (sockets, store, modelA, modelB) ->
      modelB.on 'set', '_test.text', ->
        modelB.delOT '_test.text', 2, 3
      modelA.set '_test.text', modelA.ot('abcdefghijk')
      modelA.delOT '_test.text', 1, 3
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
      modelC.on 'insertOT', '_test.text', ->
        didInsert = true
        createModelB() if didSet
      modelA.set '_test.text', modelA.ot 'abcdefg'
      modelA.insertOT '_test.text', 1, 'xyz'

  # TODO: Get this passing again!!!

  it 'an OT op in window A should be reflected in the data of a window Bs browser model that loads after window A and its OT op', (done) ->
    browserRacer = require '../src/racer.browser'
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
      modelC.on 'insertOT', '_test.text', ->
        didInsert = true
        createModelB() if didSet
      modelA.set '_test.text', modelA.ot 'abcdefg'
      modelA.insertOT '_test.text', 1, 'xyz'

#  # TODO ## Realtime mode conflicts (w/STM) ##
#
#  # TODO ## Do Refs ##
#
#  # TODO Speculative workspaces with immediate OT
#  # TODO Gate OT behind STM
