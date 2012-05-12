{expect, clearRequireCache} = require '../util'
{finishAfter} = require '../../lib/util/async'
{createBrowserRacer, mockSocketEcho, mockFullSetup, createBrowserModel} = require '../util/model'

clearRequireCache()
racer = require '../../lib/racer'
otPlugin = require '../../lib/ot'
racer.use otPlugin
plugins = [otPlugin]
{Model} = createBrowserRacer(plugins).protected

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
    [model, sockets] = mockSocketEcho '0', {plugins}
    model.ot 'some.ot.path', 'abcdef'
    model.on 'otInsert', 'some.ot.path', (pos, insertedStr) ->
      expect(insertedStr).to.equal 'try'
      expect(pos).to.equal 1
      sockets._disconnect()
      done()
    sockets.emit 'otOp', path: 'some.ot.path', op: [{i: 'try', p: 1}], v: 0

  it 'client model should emit a otDel event when it receives an OT message from the server with an otDel op', (done) ->
    [model, sockets] = mockSocketEcho '0', {plugins}
    model.ot 'some.ot.path', 'abcdef'
    model.on 'otDel', 'some.ot.path', (pos, strToDel) ->
      expect(strToDel).to.equal 'bcd'
      expect(pos).to.equal 1
      sockets._disconnect()
      done()
    sockets.emit 'otOp', path: 'some.ot.path', op: [{d: 'bcd', p: 1}], v: 0

  describe 'connected to a store', ->
    beforeEach (done) ->
      racer.use plugin for plugin in plugins
      @store = racer.createStore()
      @store.flush done

    afterEach (done) ->
      @store.flush done

    # TODO: This test should pass; right now OT operations don't work on server-side models
    # 
    # it 'otInsert events should be emitted in server-side subscribed models', (done) ->
    #   model = @store.createModel()
    #   model.subscribe 'test', (err, test) ->
    #     test.on 'otInsert', 'text', (pos, inserted) ->
    #       expect(pos).to.equal 1
    #       expect(inserted).to.equal 'def'
    #       expect(test.get 'text').to.equal 'adefbc'
    #       done()
    #     test.ot 'text', 'abc'
    #     test.otInsert 'text', 1, 'def'

    it 'otInsert events should be emitted in remote subscribed models XXX', (done) ->
      mockFullSetup @store, done, plugins, (modelA, modelB, done) ->
        modelB.on 'otInsert', '_test.text', (pos, insertedStr) ->
          expect(insertedStr).to.equal 'xyz'
          expect(pos).to.equal 1
          expect(modelB.get '_test.text').to.equal 'axyzbcdef'
          done()
        modelA.ot '_test.text', 'abcdef'
        modelA.otInsert '_test.text', 1, 'xyz'

    testOtOps = (options, callback, beforeDone) ->
      return (done) ->
        testContext = this
        mockFullSetup @store, done, plugins, (modelA, modelB, done) ->
          finish = finishAfter 2, ->
            textA = modelA.get '_test.text'
            textB = modelB.get '_test.text'
            if options.expected
              expect(textA).to.equal options.expected
            expect(textA).to.equal textB
            return beforeDone.call testContext, modelA, modelB, done  if beforeDone
            done()

          [modelA, modelB].forEach (model) ->
            onOp = finishAfter options.numOps + 1, finish
            model.on 'otInsert', '_test.text', -> onOp()
            model.on 'otDel', '_test.text', -> onOp()
            model.on 'set', '_test.text', -> onOp()

          callback.call testContext, modelA, modelB

    it '1 otInsert by window A and 1 otInsert by window B on the same path should result in the same "valid" text in both windows after both ops have propagated, transformed, and applied both ops',
      testOtOps numOps: 2, expected: 'axyzbtuvcdef', (modelA, modelB) ->
        modelB.on 'set', '_test.text', ->
          modelB.otInsert '_test.text', 2, 'tuv'
        modelA.ot '_test.text', 'abcdef'
        modelA.otInsert '_test.text', 1, 'xyz'

    it '1 otInsert by window A and 1 otDel by window B on the same path should result in the same "valid" text in both windows after both ops have propagated, transformed, and applied both ops',
      testOtOps numOps: 2, expected: 'atuvef', (modelA, modelB) ->
        modelB.on 'set', '_test.text', ->
          modelB.otInsert '_test.text', 2, 'tuv'
        modelA.ot '_test.text', 'abcdef'
        modelA.otDel '_test.text', 1, 3

    it '1 otDel by window A and 1 otDel by window B on the same path should result in the same "valid" text in both windows after both ops have propagated, transformed, and applied both ops',
      testOtOps numOps: 2, expected: 'afghijk', (modelA, modelB) ->
        modelB.on 'set', '_test.text', ->
          modelB.otDel '_test.text', 2, 3
        modelA.ot '_test.text', 'abcdefghijk'
        modelA.otDel '_test.text', 1, 3

    it 'an OT op in window A should be reflected in the data of a window Cs server model that loads after window A and its OT op',
      testOtOps numOps: 1, (modelA, modelB) ->
        modelA.ot '_test.text', 'abcdefg'
        modelA.otInsert '_test.text', 1, 'xyz'
      , (modelA, modelB, done) ->
        modelC = @store.createModel()
        testPath = modelA.dereference '_test.text'
        modelC.subscribe testPath, ->
          expect(modelC.get testPath).to.equal 'axyzbcdefg'
          done()

    it 'an OT op in window A should be reflected in the data of a window Cs browser model that loads after window A and its OT op',
      testOtOps numOps: 1, (modelA, modelB) ->
        modelA.ot '_test.text', 'abcdefg'
        modelA.otInsert '_test.text', 1, 'xyz'
      , (modelA, modelB, done) ->
        testPath = modelA.dereference '_test.text'
        createBrowserModel @store, testPath, plugins, (modelC) ->
          expect(modelC.get testPath).to.equal 'axyzbcdefg'
          done()

   # # TODO ## Realtime mode conflicts (w/STM) ##

   # # TODO Speculative workspaces with immediate OT
