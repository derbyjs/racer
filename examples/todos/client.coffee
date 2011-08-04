rally = require 'rally'
addTodo = ->

rally.onload = ->
  model = rally.model
  newTodo = document.getElementById 'new-todo'
  todoList = document.getElementById 'todos'
  
  model.set '_todos', model.ref '_group.todoList'
  
  todoHtml = ({id, text, completed}) ->
    liClass = 'completed' if completed
    """<li id=#{id} class=#{liClass}><input type=checkbox id=#{id}-check>
    <label for=#{id}-check>#{text}</label><button>Delete</button>"""
  
  updateTodos = ->
    todoList.innerHTML = (todoHtml todo for todo in model.get '_todos').join ''
  model.on 'push', '_group.todos', updateTodos
  updateTodos()
  
  addTodo = ->
    nextId = model.get '_group.nextId'
    model.set '_group.nextId', nextId + 1
    model.push '_group.todoList',
      id: nextId
      completed: false
      text: newTodo.value
    newTodo.value = ''

if document.addEventListener
  addListener = (el, type, listener) ->
    el.addEventListener type, listener, false
else
  addListener = (el, type, listener) ->
    el.attachEvent 'on' + type, (e) ->
      listener e || event
