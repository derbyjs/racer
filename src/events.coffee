# We use subscriptions so we don't need to keep explicit references to fn and context as a necessity to removeListener in the future.
# Instead, we return a new subscription when we bind a listener to an event using `on`.
#     var subscription = emitter.on("ev", function () {});
# Then, later we can just `cancel` a subscription.
#     subscription.cancel();
Subscription = (@target, @event, @fn, @context) ->
  this.active = true
  return

Subscription::cancel = ->
  return unless this.active
  @target.removeListener @event, @fn, @context
  @active = false

module.exports = events =
  Subscription: Subscription
  on: (ev, fn, context) ->
    ev2cb = @_listeners ||= {}
    cbs = ev2cb[ev] ||= []
    cbs.push [fn, context]
    return new Subscription @, ev, fn, context
  removeListener: (ev, fn, context) ->
    return @ unless ev2cb = @_listeners
    return @ unless cbs = ev2cb[ev]
    i = cbs.length
    while i--
      cb = cbs[i]
      cbs.splice i, 1 if cb[0] == fn && cb[1] == context
    return @
  trigger: (ev, args...) ->
    ev2cb = @_listeners
    lastArg = args[args.length-1]
    mute = null
    if lastArg && typeof lastArg == 'object'
      mute = lastArg.mute
    return @ unless ev2cb
    return @ unless cbs = ev2cb[ev]
    i = cbs.length
    while i--
      cb = cbs[i]
      continue if mute && @_shouldMute(mute, cb)
      cb[0].apply cb[1], args
    return @
  _shouldMute: (mute, cb) ->
    if j = mute.length
      while j--
        return true if @_shouldMute mute[j], cb
    else if mute.target == @ && (!(mute.context && cb[1]) || mute.context == cb[1]) && mute.fn == cb[0]
      return true
    return false
  once: (ev, fn, context) ->
    subsc = @on ev, ->
      subsc.cancel()
      fn.apply @, Array::slice.call arguments
    , context
    return subsc
