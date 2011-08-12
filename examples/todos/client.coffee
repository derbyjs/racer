rally = require 'rally'
addTodo = ->
check = ->

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
    <span class=todo>
      <label><input id=check#{id} type=checkbox #{checked} onchange=check(this,#{id})><i></i></label>
      <span id=text#{id} contenteditable=true>#{text}</span>
    </span>
    <button class=delete>Delete</button>"""
  
  # Render the initial list
  todoList.html (todoHtml todo for todo in model.get '_group.todoList').join('')
  
  model.on 'push', '_group.todoList', (value) ->
    todoList.append todoHtml value
  
  model.on 'set', '_group.todos.*.completed', (id, value) ->
    $("##{id}").toggleClass 'completed', value
    $("#check#{id}").prop 'checked', value
  
  model.on 'set', '_group.todos.*.text', (id, value) ->
    el = $ "#text#{id}"
    return if el.is ':focus'
    el.text value
  
  addTodo = ->
    model.push '_group.todoList',
      id: model.incr '_group.nextId'
      completed: false
      text: newTodo.val()
    newTodo.val ''
  
  check = (checkbox, id) ->
    model.set "_group.todos.#{id}.completed", checkbox.checked
  
  lastHtml = ''
  onkey = (e) ->
    html = content.html()
    if html != lastHtml
      lastHtml = html
      target = e.target
      return unless target.contentEditable
      text = target.textContent || target.innerText
      id = target.parentNode.parentNode.id
      model.set "_group.todos.#{id}.text", text
  # Paste and dragover events are fired before the HTML is actually updated
  onkeyDelayed = (e) ->
    setTimeout onkey, 10, e
  
  $(document)
    .keydown(onkey)
    .keyup(onkey)
    .bind('paste', onkeyDelayed)
    .bind('dragover', onkeyDelayed)

