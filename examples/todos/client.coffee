rally = require 'rally'
addTodo = ->
check = ->
del = ->

# Calling $() with a function is equivalent to $(document).ready() in jQuery
$ rally.ready ->
  model = rally.model
  newTodo = $ '#new-todo'
  todoList = $ '#todos'
  content = $ '#content'
  
  todoHtml = ({id, text, completed}) ->
    if completed
      completed = 'completed'
      checked = 'checked'
    else
      completed = ''
      checked = ''
    """<li id=#{id} class=#{completed}>
    <div class=cell><div class=todo>
      <label><input id=check#{id} type=checkbox #{checked} onchange=check(this,#{id})><i></i></label>
      <div id=text#{id} data-id=#{id} contenteditable=true>#{text}</div>
    </div></div>
    <div class=cell><button class=delete onclick=del(#{id})>Delete</button></div>"""
  
  # Render the initial list
  todoList.html (todoHtml todo for todo in model.get '_group.todoList').join('')
  
  model.on 'push', '_group.todoList', (value) ->
    todoList.append todoHtml value
  
  model.on 'set', '_group.todos.*.completed', (id, value) ->
    $("##{id}").toggleClass 'completed', value
    $("#check#{id}").prop 'checked', value
  
  model.on 'del', '_group.todos.*', (id) ->
    $("##{id}").remove()
  
  model.on 'set', '_group.todos.*.text', (id, value) ->
    el = $ "#text#{id}"
    return if el.is ':focus'
    el.html value
  
  addTodo = ->
    model.push '_group.todoList',
      id: model.incr '_group.nextId'
      completed: false
      text: newTodo.val()
    newTodo.val ''
  
  check = (checkbox, id) ->
    model.set "_group.todos.#{id}.completed", checkbox.checked
  
  del = (id) ->
    model.del "_group.todos.#{id}"
  
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
  
  checkShortcuts = (e) ->
    return unless e.metaKey || e.ctrlKey
    return unless command = `
      e.which === 66 ? 'bold' :
      e.which === 73 ? 'italic' : null`
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

