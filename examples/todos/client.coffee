rally = require 'rally'
addTodo = ->
check = ->

window.onload = rally.ready ->
  model = rally.model
  newTodo = document.getElementById 'new-todo'
  todoList = document.getElementById 'todos'
  
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
    todoList.innerHTML = (todoHtml todo for todo in model.get '_todoList').join ''
  model.on 'push', '_todoList', updateTodos
  model.on 'set', '_todoList.**', updateTodos
  updateTodos()
  
  addTodo = ->
    nextId = model.get '_group.nextId'
    model.set '_group.nextId', nextId + 1
    model.push '_group.todoList',
      id: nextId
      completed: false
      text: newTodo.value
    newTodo.value = ''
  
  check = (checkbox) ->
    id = checkbox.parentNode.parentNode.id
    model.set "_group.todos.#{id}.completed", checkbox.checked

if document.addEventListener
  addListener = (el, type, listener) ->
    el.addEventListener type, listener, false
else
  addListener = (el, type, listener) ->
    el.attachEvent 'on' + type, (e) ->
      listener e || event
