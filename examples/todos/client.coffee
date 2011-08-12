rally = require 'rally'
addTodo = ->
check = ->

# Calling $() with a function is equivalent to $(document).ready() in jQuery
$ rally.ready ->
  model = rally.model
  newTodo = $ '#new-todo'
  todoList = $ '#todos'
  
  model.set '_todoList', model.ref '_group.todoList'
  
  todoHtml = ({id, text, completed}) ->
    if completed
      text = "<s>#{text}</s>"
      checked = 'checked'
    else
      checked = ''
    """<li id=#{id}>
    <label><input type=checkbox #{checked} onchange=check(this)><i></i> #{text}</label>
    <button class=delete>Delete</button>"""
  
  updateTodos = ->
    todoList.html (todoHtml todo for todo in model.get '_todoList').join ''
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
  
  check = (checkbox) ->
    id = checkbox.parentNode.parentNode.id
    model.set "_group.todos.#{id}.completed", checkbox.checked

