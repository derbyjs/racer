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
    """<li id=#{id} class=#{completed}><table width=100%><tr>
    <td class=handle width=0><td width=100%><div class=todo>
      <label><input id=check#{id} type=checkbox #{checked} onchange=check(this,#{id})><i></i></label>
      <div id=text#{id} data-id=#{id} contenteditable=true>#{text}</div>
    </div>
    <td width=0><button class=delete onclick=del(#{id})>Delete</button></table>"""
  
  # Render the initial list
  todoList.html (todoHtml todo for todo in model.get '_group.todoList').join('')
  
  
  ## Update the DOM when the model changes ##
  
  model.on 'push', '_group.todoList', (value) ->
    todoList.append todoHtml value
  
  model.on 'set', '_group.todos.*.completed', (id, value) ->
    $("##{id}").toggleClass 'completed', value
    $("#check#{id}").prop 'checked', value
  
  model.on 'remove', '_group.todoList', ({id}) ->
    $("##{id}").remove()
  
  model.on 'move', '_group.todoList', ({id, index}, to) ->
    target = todoList.children().get to
    # Don't move if the item is already in the right position
    return if id.toString() is target.id
    if index > to && to != -1
      $("##{id}").insertBefore target
    else
      $("##{id}").insertAfter target
  
  model.on 'set', '_group.todos.*.text', (id, value) ->
    el = $ "#text#{id}"
    return if el.is ':focus'
    el.html value

  
  ## Update the model in response to DOM events ##
  
  addTodo = ->
    model.push '_group.todoList',
      id: model.incr '_group.nextId'
      completed: false
      text: newTodo.val()
    newTodo.val ''
  
  check = (checkbox, id) ->
    model.set "_group.todos.#{id}.completed", checkbox.checked
    # Move the item to the bottom if it was checked off
    model.move '_group.todoList', {id}, -1 if checkbox.checked
  
  del = (id) ->
    model.remove "_group.todoList", id: id
  
  todoList.sortable
    handle: '.handle'
    axis: 'y'
    containment: '#dragbox'
    update: (e, ui) ->
      item = ui.item[0]
      to = todoList.children().index(item)
      model.move '_group.todoList', {id: item.id}, to
  
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
    return unless command = `
      code === 66 ? 'bold' :
      code === 73 ? 'italic' :
      code === 32 ? 'removeFormat' :
      code === 220 ? 'removeFormat' : null`
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

