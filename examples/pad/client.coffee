racer = require 'racer'

# racer.ready returns a callback function for a DOM ready event. Its callback
# will only be called once both the model data are loaded and the event that
# it is passed to occurs.
# Alternatively, racer.onload can be set to a function that only waits for
# the model data to be loaded.
# Calling $() with a function is equivalent to $(document).ready() in jQuery
racer.onready = ->
  model = racer.model

  editor = document.getElementById 'editor'

  ## Update the model in response to DOM events ##

  applyChange = (newval) ->
    oldval = model.get '_room.text'
    return if oldval == newval
    commonStart = 0
    commonStart++ while oldval.charAt(commonStart) == newval.charAt(commonStart)

    commonEnd = 0
    commonEnd++ while oldval.charAt(oldval.length - 1 - commonEnd) == newval.charAt(newval.length - 1 - commonEnd) and
      commonEnd + commonStart < oldval.length and commonEnd + commonStart < newval.length

    model.delOT '_room.text', oldval.length - commonStart - commonEnd, commonStart unless oldval.length == commonStart + commonEnd
    model.insertOT '_room.text', newval[commonStart ... newval.length - commonEnd], commonStart unless newval.length == commonStart + commonEnd

  setup = (snapshot) ->
    editor.disabled = false
    prevvalue = editor.value = snapshot

    replaceText = (newText, transformCursor) ->
      newSelection = [
        transformCursor elem.selectionStart
        transformCursor elem.selectionEnd
      ]

      scrollTop = elem.scrollTop
      elem.value = newText
      elem.scrollTop = scrollTop if elem.scrollTop != scrollTop
      [elem.selectionStart, elem.selectionEnd] = newSelection

    model.on 'insertOT', '_room.text', (text, pos) ->
      transformCursor = (cursor) ->
        if pos <= cursor
          cursor + text.length
        else
          cursor

      replaceText elem.value[...pos] + text + elem.value[pos..], transformCursor

    model.on 'delOT', (text, pos) ->
      transformCursor = (cursor) ->
        if pos < cursor
          cursor - Math.min(text.length, cursor - pos)
        else
          cursor

      replaceText elem.value[...pos] + elem.value[pos + text.length..], transformCursor

    genOp = (e) ->
      onNextTick = (fn) -> setTimeout fn, 0
      onNextTick ->
        if editor.value != prevValue
          prevValue = editor.value
          applyChange editor.value.replace /\r\n/g, '\n'

    for event in ['textInput', 'keydown', 'keyup', 'select', 'cut', 'paste']
      if editor.addEventListener
        editor.addEventListener event, genOp, false
      else
        editor.attachEvent 'on'+event, genOp

  model.on 'open', '_room', setup

racer.init @init
delete @init
