Model = require 'Model'
should = require 'should'
util = require './util'
wrapTest = util.wrapTest
{mockSocketModels, fullyWiredModels} = require './util/model'
{BrowserSocketMock} = require './util/mocks'

flushRedis = (done) ->
  redis = require('redis').createClient()
  redis.select 2, (err) ->
    throw err if err
    redis.flushdb (err) ->
      throw err if err
      redis.quit()
      done()

module.exports =
  setup: (done) ->
    flushRedis done
  teardown: (done) ->
    flushRedis done

  ## Server-side OT ##
  '''model.set(path, model.ot(val)) should initialize the doc version
  to 0 and the initial value to val if the path is undefined @ot''': (done) ->
    model = new Model
    model.set 'some.ot.path', model.ot('hi')
    model.get('some.ot.path').should.equal 'hi'
    model.isOtPath('some.ot.path').should.be.true
    model.version('some.ot.path').should.equal 0
    done()

#  'model.subscribe(OTpath) should get the latest OT version doc if
#  the path is specified before-hand as being OT': -> # TODO
  
  ## Client-side OT ##
  '''model.insertOT(path, str, pos, callback) should result in a new
  string with str inserted at pos @ot''': (done) ->
    model = new Model
    model.socket = emit: -> # Stub
    model.set 'some.ot.path', model.ot('abcdef')
    model.insertOT 'some.ot.path', 'xyz', 1
    model.get('some.ot.path').should.equal 'axyzbcdef'
    done()

  '''model.delOT(path, len, pos, callback) should result in a new
  string with str removed at pos @ot''': (done) ->
    model = new Model
    model.socket = emit: -> # Stub
    model.set 'some.ot.path', model.ot('abcdef')
    model.delOT 'some.ot.path', 3, 1
    model.get('some.ot.path').should.equal 'aef'
    done()

  '''model should emit an insertOT event when it calls model.insertOT
  locally @ot''': (done) ->
    model = new Model
    model.socket = emit: -> # Stub
    model.set 'some.ot.path', model.ot('abcdef')
    model.on 'insertOT', 'some.ot.path', (insertedStr, pos) ->
      insertedStr.should.equal 'xyz'
      pos.should.equal 1
      done()
    model.insertOT 'some.ot.path', 'xyz', 1

  '''model should emit a delOT event when it calls model.delOT
  locally @ot''': (done) ->
    model = new Model
    model.socket = emit: -> # Stub
    model.set 'some.ot.path', model.ot('abcdef')
    model.on 'delOT', 'some.ot.path', (deletedStr, pos) ->
      deletedStr.should.equal 'bcd'
      pos.should.equal 1
      done()
    model.delOT 'some.ot.path', 3, 1

  ## Client-server OT communication ##
  '''client model should emit an insertOT event when it receives
  an OT message from the server with an insertOT op @ot''': (done) ->
    [sockets, model] = mockSocketModels 'model'
    model.set 'some.ot.path', model.ot('abcdef')
    model.on 'insertOT', 'some.ot.path', (insertedStr, pos) ->
      insertedStr.should.equal 'try'
      pos.should.equal 1
      sockets._disconnect()
      done()
    sockets.emit 'otOp', path: 'some.ot.path', op: [{i: 'try', p: 1}], v: 0

  '''client model should emit a delOT event when it receives
  an OT message from the server with an delOT op @ot''': (done) ->
    [sockets, model] = mockSocketModels 'model'
    model.set 'some.ot.path', model.ot('abcdef')
    model.on 'delOT', 'some.ot.path', (strToDel, pos) ->
      strToDel.should.equal 'bcd'
      pos.should.equal 1
      sockets._disconnect()
      done()
    sockets.emit 'otOp', path: 'some.ot.path', op: [{d: 'bcd', p: 1}], v: 0

  '''local client model insertOT's should result in the same
  text in sibling windows @ot''': (done) ->
    numModels = 2
    fullyWiredModels numModels, (sockets, store, modelA, modelB) ->
      modelA.set '_test.text', modelA.ot('abcdef')
      modelB.on 'insertOT', '_test.text', (insertedStr, pos) ->
        insertedStr.should.equal 'xyz'
        pos.should.equal 1
        modelB.get('_test.text').should.equal 'axyzbcdef'
        sockets._disconnect()
        store.disconnect()
        done()
      modelA.insertOT '_test.text', 'xyz', 1

  ## Validity ##
  '''1 insertOT by window A and 1 insertOT by window B on the
  same path should result in the same 'valid' text in both windows
  after both ops have propagated, transformed, and applied both
  ops @ot''': (done) ->
    numModels = 2
    fullyWiredModels numModels, (sockets, store, modelA, modelB) ->
      modelB.on 'set', '_test.text', ->
        modelB.insertOT '_test.text', 'tuv', 2
      modelA.set '_test.text', modelA.ot('abcdef')

      models = [modelA, modelB]
      models.forEach (model, i) ->
        otherModel = models[i+1] || models[i-1]
        model.__events__ = 0
        model._on 'insertOT', ([path, insertedStr, pos], isRemote) ->
          return unless path == '_test.text'
          return if ++model.__events__ < 2
          model.__final__ = model.get '_test.text'
          if model.__events__ == otherModel.__events__
            model.__final__.should.equal otherModel.__final__
            sockets._disconnect()
            store.disconnect()
            done()
      modelA.insertOT '_test.text', 'xyz', 1

  '''1 insertOT by window A and 1 delOT by window B on the
  same path should result in the same 'valid' text in both windows
  after both ops have propagated, transformed, and applied both
  ops @ot''': (done) ->
    numModels = 2
    fullyWiredModels numModels, (sockets, store, modelA, modelB) ->
      modelB.on 'set', '_test.text', ->
        modelB.insertOT '_test.text', 'tuv', 2
      modelA.set '_test.text', modelA.ot('abcdef')

      modelA.delOT '_test.text', 3, 1
      setTimeout ->
        modelB.get('_test.text').should.equal modelA.get('_test.text')
        sockets._disconnect()
        store.disconnect()
        done()
      , 200

  '''1 delOT by window A and 1 delOT by window B on the
  same path should result in the same 'valid' text in both windows
  after both ops have propagated, transformed, and applied both
  ops @ot''': (done) ->
    numModels = 2
    fullyWiredModels numModels, (sockets, store, modelA, modelB) ->
      modelB.on 'set', '_test.text', ->
        modelB.delOT '_test.text', 3, 2
      modelA.set '_test.text', modelA.ot('abcdefghijk')
      modelA.delOT '_test.text', 3, 1
      setTimeout ->
        modelB.get('_test.text').should.equal modelA.get('_test.text')
        sockets._disconnect()
        store.disconnect()
        done()
      , 200

  '''an OT op in window A should be reflected in the data of
  a window B's server model that loads after window A and its OT op @ot''': (done) ->
    fullyWiredModels 2, (sockets, store, modelA, modelC) ->

      createModelB = ->
        modelB = store.createModel()
        ref = modelC._adapter._data.world._test.$r
        modelB.subscribe _test: ref, ->
          modelB.get('_test.text').should.equal 'axyzbcdefg'
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
      modelA.insertOT '_test.text', 'xyz', 1

  '''an OT op in window A should be reflected in the data of
  a window B's browser model that loads after window A and its OT op @ot''': (done) ->
    browserRacer = require '../src/racer.browser'
    fullyWiredModels 2, (sockets, store, modelA, modelC) ->

      createModelB = ->
        serverModelB = store.createModel()
        ref = modelC._adapter._data.world._test.$r
        serverModelB.subscribe _test: ref, ->
          serverModelB.bundle (bundle) ->
            bundle = JSON.parse bundle
            bundle.socket = new BrowserSocketMock sockets
            browserModelB = new Model
            browserRacer.init.call model: browserModelB, bundle
            browserModelB.get('_test.text').should.equal 'axyzbcdefg'

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
      modelA.insertOT '_test.text', 'xyz', 1


#  # TODO ## Realtime mode conflicts (w/STM) ##
#
#  # TODO ## Do Refs ##
#
#  # TODO Speculative workspaces with immediate OT
#  # TODO Gate OT behind STM
