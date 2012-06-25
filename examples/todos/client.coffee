racer = require 'racer'
todoHtml = require('./shared').todoHtml

process.nextTick ->
  racer.init @init
  delete @init

# racer.ready returns a callback function for a DOM ready event. Its callback
# will only be called once both the model data are loaded and the event that
# it is passed to occurs.
# Alternatively, racer.onload can be set to a function that only waits for
# the model data to be loaded.
# Calling $() with a function is equivalent to $(document).ready() in jQuery
$ racer.ready (model) ->
  newTodo = $ '#new-todo'
  todoList = $ '#todos'
  content = $ '#content'
  overlay = $ '#overlay'
  list = model.at '_todoList'


  ## Update the DOM when the model changes ##

  model.on 'connectionStatus', (connected, canConnect) ->
    overlay.html(if connected
      ''
    else if canConnect
      '<p id=info>Offline<span id=reconnect> &ndash; <a href=# onclick="return todos.connect()">Reconnect</a></span>'
    else
      '<p id=info>Unable to reconnect &ndash; <a href=javascript:window.location.reload()>Reload</a>'
    )

  list.on 'push', (value) ->
    todoList.append todoHtml(value)

  list.on 'insert', (index, value) ->
    todoList.children().eq(index).before todoHtml(value)

  model.on 'set', '_group.todos.*.completed', (id, value) ->
    $("##{id}").toggleClass 'completed', value
    $("#check#{id}").prop 'checked', value

  list.on 'remove', (index, howMany, [id]) ->
    $("##{id}").remove()

  list.on 'move', (from, to, howMany, [id]) ->
    target = todoList.children().get to
    # Don't move if the item is already in the right position
    return if id.toString() is target.id
    if from > to && to != -1
      $("##{id}").insertBefore target
    else
      $("##{id}").insertAfter target

  model.on 'set', '_group.todos.*.text', (id, value) ->
    el = $ "#text#{id}"
    return if el.is ':focus'
    el.html value

  ## Update the model in response to DOM events ##

  window.todos =

    connect: ->
      reconnect = document.getElementById 'reconnect'
      reconnect.style.display = 'none'
      # Hide the reconnect link for a second so it looks like something is going on
      setTimeout (-> reconnect.style.display = 'inline'), 1000
      model.socket.connect()
      return false

    addTodo: ->
      # Don't add a blank todo
      return unless text = htmlEscape newTodo.val()
      newTodo.val ''
      # Insert the new todo before the first completed item in the list
      items = list.get()
      for todo, i in items
        break if todo.completed
      todo =
        id: model.incr('_group.nextId').toString()
        completed: false
        text: text
      if i == items.length
        # Append to the end if there are no completed items
        list.push todo
      else
        list.insert i, todo

    check: (checkbox, id) ->
      model.set "_group.todos.#{id}.completed", checkbox.checked
      # Move the item to the bottom if it was checked off
      list.move {id}, -1 if checkbox.checked

    del: (id) ->
      list.remove id: id

  todoList.sortable
    handle: '.handle'
    axis: 'y'
    containment: '#dragbox'
    update: (e, ui) ->
      item = ui.item[0]
      to = todoList.children().index(item)
      list.move {id: item.id}, to

  # Watch for changes to the contenteditable fields
  lastHtml = ''
  checkChanged = (e) ->
    html = content.html()
    return if html == lastHtml
    lastHtml = html
    target = e.target
    return unless id = target.getAttribute 'data-id'
    text = target.innerHTML
    model.set "_group.todos.#{id}.text", text
  # Paste and dragover events are fired before the HTML is actually updated
  checkChangedDelayed = (e) ->
    setTimeout checkChanged, 10, e

  # Shortcuts
  # Bold: Ctrl/Cmd + B
  # Italic: Ctrl/Cmd + I
  # Clear formatting: Ctrl/Cmd + Space -or- Ctrl/Cmd + \
  checkShortcuts = (e) ->
    return unless e.metaKey || e.ctrlKey
    code = e.which
    return unless command = (switch code
      when 66 then 'bold'
      when 73 then 'italic'
      when 32 then 'removeFormat'
      when 220 then 'removeFormat'
      else null
    )
    document.execCommand command, false, null
    e.preventDefault() if e.preventDefault
    return false

  content
    .keydown(checkShortcuts)
    .keydown(checkChanged)
    .keyup(checkChanged)
    .bind('paste', checkChangedDelayed)
    .bind('dragover', checkChangedDelayed)

  # Tell Firefox to use elements for styles instead of CSS
  # See: https://developer.mozilla.org/en/Rich-Text_Editing_in_Mozilla
  document.execCommand 'useCSS', false, true
  document.execCommand 'styleWithCSS', false, false


  htmlEscape = (s) ->
    unless s? then '' else s.toString().replace /&(?!\s)|</g, (s) ->
      if s is '&' then '&amp;' else '&lt;'
