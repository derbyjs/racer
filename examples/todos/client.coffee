rally = require 'rally'
addTodo = ->
check = ->

# Calling $() with a function is equivalent to $(document).ready() in jQuery
$ rally.ready ->
  model = rally.model
  newTodo = $ '#new-todo'
  todoList = $ '#todos'
  
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
    nextId = model.get '_group.nextId'
    model.set '_group.nextId', nextId + 1
    model.push '_group.todoList',
      id: nextId
      completed: false
      text: newTodo.val()
    newTodo.val ''
  
  check = (checkbox, id) ->
    model.set "_group.todos.#{id}.completed", checkbox.checked

