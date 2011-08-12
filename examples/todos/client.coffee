rally = require 'rally'
addTodo = ->
check = ->

# Calling $() with a function is equivalent to $(document).ready() in jQuery
$ rally.ready ->
  model = rally.model
  newTodo = $ '#new-todo'
  todoList = $ '#todos'
  content = $ '#content'
  
  model.set '_todoList', model.ref '_group.todoList'
  
  updateTodos = ->
    html = ''
    for {id, text, completed} in model.get '_todoList'
      if completed
        wrap = 's'
        checked = 'checked'
      else
        wrap = 'span'
        checked = ''
      html = html + """<li id=#{id}>
      <span class=todo>
        <label><input type=checkbox #{checked} onchange=check(this,#{id})><i></i></label>
        <#{wrap} contenteditable=true>#{text}</#{wrap}>
      </span>
      <button class=delete>Delete</button>"""
    todoList.html html
  
  model.on 'push', '_todoList', updateTodos
  model.on 'set', '_todoList.**', updateTodos
  updateTodos()
  
  addTodo = ->
    model.push '_group.todoList',
      id: model.incr '_group.nextId'
      completed: false
      text: newTodo.val()
    newTodo.val ''
  
  check = (checkbox, id) ->
    model.set "_group.todos.#{id}.completed", checkbox.checked
  
  lastHtml
  onkeyevent = (e) ->
    html = content.html()
    if html != lastHtml
      lastHtml = html
      console.log e.target
  
  $(document)
    .keydown(onkeyevent)
    .keyup(onkeyevent)
    .bind('paste', onkeyevent)
    .bind('dragover', onkeyevent)

