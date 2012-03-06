racer = require 'racer'
racer.use require 'racer/lib/ot'

process.nextTick ->
  racer.init @init
  delete @init

racer.on 'ready', (model) ->

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

    unless oldval.length == commonStart + commonEnd
      model.otDel '_room.text', commonStart,
        oldval.length - commonStart - commonEnd

    unless newval.length == commonStart + commonEnd
      model.otInsert '_room.text', commonStart,
        newval.substr commonStart, newval.length - commonEnd

  editor.disabled = false
  prevvalue = editor.value = model.get '_room.text'

  replaceText = (newText, transformCursor) ->
    newSelection = [
      transformCursor editor.selectionStart
      transformCursor editor.selectionEnd
    ]
    scrollTop = editor.scrollTop
    editor.value = newText
    editor.scrollTop = scrollTop if editor.scrollTop != scrollTop
    [editor.selectionStart, editor.selectionEnd] = newSelection

  model.on 'otInsert', '_room.text', (pos, text, isLocal) ->
    return if isLocal
    replaceText editor.value[...pos] + text + editor.value[pos..], (cursor) ->
      if pos <= cursor then cursor + text.length else cursor

  model.on 'otDel', '_room.text', (pos, text, isLocal) ->
    return if isLocal
    replaceText editor.value[...pos] + editor.value[pos + text.length..], (cursor) ->
      if pos < cursor then cursor - Math.min(text.length, cursor - pos) else cursor

  genOp = (e) ->
    setTimeout ->
      if editor.value != prevValue
        prevValue = editor.value
        applyChange editor.value.replace /\r\n/g, '\n'
    , 0

  for event in ['input', 'keydown', 'keyup', 'select', 'cut', 'paste']
    if editor.addEventListener
      editor.addEventListener event, genOp, false
    else
      editor.attachEvent 'on' + event, genOp
