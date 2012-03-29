# NOTE: All racer modules for the browser should be included in racer.coffee
# and not in this file

# Static isReady and model variables are used, so that the ready function
# can be called anonymously. This assumes that only one instace of Racer
# is running, which should be the case in the browser.
isReady = model = null

exports = module.exports = (racer) ->
  racer.merge

    # `init` should be called (by the developer) with the specified arguments
    # when the browser loads the app.
    # `socket` argument makes it easier to test - see test/util/model
    init: ([clientId, memory, count, onLoad, startId, ioUri], socket) ->
      model = new racer.Model
      model._clientId = clientId
      model._startId = startId
      model._memory.init memory
      model._count = count

      for item in onLoad
        method = item.shift()
        model[method] item...

      racer.emit 'init', model

      model._setSocket socket || io.connect ioUri,
        'reconnection delay': 100
        'max reconnection attempts': 20
        query: 'clientId=' + clientId

      isReady = true
      racer.emit 'ready', model
      return racer

    # This returns a function that can be passed to a DOM ready function
    ready: (onready) -> ->
      if isReady
        connected = model.socket.socket.connected
        onready model
        # Republish the Socket.IO connect event after the ready callback
        # if Socket.IO previously connected
        model.socket.socket.publish 'connect'  if connected
        return
      racer.on 'ready', onready

exports.useWith = server: false, browser: true
