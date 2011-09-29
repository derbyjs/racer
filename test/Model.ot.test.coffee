Model = require 'Model'
should = require 'should'
util = require './util'
wrapTest = util.wrapTest
mockSocketModels = require('./util/model').mockSocketModels

module.exports =
  ## Server-side OT ##
  '''model.set(path, model.ot(val)) should initialize the doc version
  to 0 and the initial value to val if the path is undefined @ot''': ->
    model = new Model
    model.set 'some.ot.path', model.ot('hi')
    model.get('some.ot.path').should.equal 'hi'
    model.isOtPath('some.ot.path').should.be.true
    model.version('some.ot.path').should.equal 0

  'model.subscribe(OTpath) should get the latest OT version doc if
  the path is specified before-hand as being OT': -> # TODO
  
  ## Client-side OT ##
  '''model.insertOT(path, str, pos, callback) should result in a new
  string with str inserted at pos @ot''': ->
    model = new Model
    model.set 'some.ot.path', model.ot('abcdef')
    model.insertOT 'some.ot.path', 'xyz', 1
    model.get('some.ot.path').should.equal 'axyzbcdef'

  '''model.delOT(path, len, pos, callback) should result in a new
  string with str removed at pos @ot''': ->
    model = new Model
    model.set 'some.ot.path', model.ot('abcdef')
    model.delOT 'some.ot.path', 3, 1
    model.get('some.ot.path').should.equal 'aef'

  '''model should emit an insertOT event when it calls model.insertOT
  locally @ot''': wrapTest (done) ->
    model = new Model
    model.set 'some.ot.path', model.ot('abcdef')
    model.on 'insertOT', 'some.ot.path', (insertedStr, pos) ->
      insertedStr.should.equal 'xyz'
      pos.should.equal 1
      done()
    model.insertOT 'some.ot.path', 'xyz', 1

  '''model should emit a delOT event when it calls model.delOT
  locally''': -> # TODO

  ## Client-server OT communication ##
  '''client model should emit an insertOT event when it receives
  an OT message from the server with an insertOT op''': -> # TODO

  '''client model should emit an delOT event when it receives
  an OT message from the server with an delOT op''': -> # TODO

  '''local client model insertOT's should result in the same
  text in sibling windows''': -> # TODO

  ## Validity ##
  '''1 insertOT by window A and 1 insertOT by window B on the
  same path should result in the same 'valid' text in both windows
  after both ops have propagated, transformed, and applied both
  ops''': -> # TODO

  '''1 insertOT by window A and 1 delOT by window B on the
  same path should result in the same 'valid' text in both windows
  after both ops have propagated, transformed, and applied both
  ops''': -> # TODO

  '''1 delOT by window A and 1 delOT by window B on the
  same path should result in the same 'valid' text in both windows
  after both ops have propagated, transformed, and applied both
  ops''': -> # TODO

  # TODO ## Realtime mode conflicts (w/STM) ##

  # TODO ## Do Refs ##

  # TODO Speculative workspaces with immediate OT
  # TODO Gate OT behind STM
