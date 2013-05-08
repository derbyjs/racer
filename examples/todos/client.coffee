racer = require 'racer'
templates = require './templates.coffee'

racer.ready (model) -> $ ->
  window.model = model

  model.on 'all', '**', console.log.bind(console)

  newTodo = $ '#new-todo'
  todoList = $ '#todos'
  content = $ '#content'
  overlay = $ '#overlay'
  list = model.at '_page.todoList'

  ## Update the DOM when the model changes ##

  model.on 'set', '_group.todos.*.completed', (id, value) ->
    $("##{id}").toggleClass 'completed', value
    $("#check#{id}").prop 'checked', value

  list.on 'insert', (index, value) ->
    todoList.children().eq(index).before templates.todo(value)

  list.on 'remove', (index, removed) ->
    $("##{todo.id}").remove() for todo in removed

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

  indexById = (id) ->
    for todo, i in list.get()
      return i if todo?.id is id
    return -1

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
      list.insert i,
        id: model.id()
        completed: false
        text: text

    check: (checkbox, id) ->
      model.set "_group.todos.#{id}.completed", checkbox.checked
      # Move the item to the bottom if it was checked off
      list.move indexById(id), -1 if checkbox.checked

    del: (id) ->
      list.remove indexById(id)

  todoList.sortable
    handle: '.handle'
    axis: 'y'
    containment: '#dragbox'
    update: (e, ui) ->
      item = ui.item[0]
      to = todoList.children().index(item)
      list.move indexById(item.id), to

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
