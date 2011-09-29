# TODO Transition from entry point model.set(path, OT.field(val)) to racer.init client bundle
# TODO Browser model methods insert + del should apply ops and send them to server
# TODO Make sure browser OT works with refs
# TODO Implement server component with socket.io as entry point - Modify Store
# TODO Server broadcasting of ops to browsers
# TODO Browser handling of remote ops
# TODO Enough hooks via exposed events on browser
# TODO Persistence to a datastore
#
# TODO Do JSON OT

Field = require './Field'

# TODO Decorate adapter?

ot = module.exports =
  proto:
    # OT text insert
    insertOT: (path, str, pos, callback) ->
      # TODO Still need to normalize path
      field = @otFields[path] ||= new Field @, path
      pos ?= 0
      op = [ { p: pos, i: str } ]
      op.callback = callback if callback
      field.submitOp op


    # OT text del
    delOT: (path, len, pos, callback) ->
      # TODO Still need to normalize path
      field = @otFields[path] ||= new Field @, path
      op = [ { p: pos, d: field.snapshot[pos...pos+length] } ]
      op.callback = callback if callback
      field.submitOp op

    ## OT field functions ##
    # model.ot initStr
    ot: (initVal) -> $ot: initVal
  

  # Socket setup
  setupSocket: (socket) ->
    self = this
    # OT callbacks
    socket.on 'otOp', ({path, op, v}) ->
      self.otFields[path].onRemoteOp op, v
    

