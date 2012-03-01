require 'es5-shim'

# NOTE: All racer modules for the browser should be included in racer.coffee

# Static isReady and model variables are used, so that the ready function
# can be called anonymously. This assumes that only one instace of Racer
# is running, which should be the case in the browser.
isReady = false

module.exports = (racer) ->
  racer.util.mergeAll racer,

    model: model = new racer.Model

    # socket argument makes it easier to test - see test/util/model fullyWiredModels
    init: ([clientId, memory, count, onLoad, startId, ioUri], socket) ->
      model._clientId = clientId
      model._startId = startId
      model._memory.init memory
      model._count = count

      for item in onLoad
        method = item.shift()
        model[method] item...

      socket ||= io.connect ioUri,
        'reconnection delay': 100
        'max reconnection attempts': 20
      model.socket = socket

      model.emit 'initialized'
      model._setSocket socket

      isReady = true
      racer.onready()
      return racer

    onready: ->
    ready: (onready) -> ->
      racer.onready = onready
      if isReady
        connected = model.socket.socket.connected
        onready()
        # Republish the Socket.IO connect event after the onready callback
        # executes in case any client code wants to use it
        model.socket.socket.publish 'connect' if connected
