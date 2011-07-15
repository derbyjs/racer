rally = require 'rally'

window.onload = ->
  model = rally.model

  todoList = document.getElementById 'todos'

  addTodo = (id, index, member) ->
    todos = model.get "groups.#{groupId}.todos"
    # TODO Add todo to user todos
    todoList # TODO Add todo to DOM

  removeTodo = (todoId) ->
    # TODO model.del "todos.#{todoId}"

  model.on 'insertAfter', "groups.#{groupId}.todos", addTodo
  model.on 'removeAfter', "groups.#{groupId}.todos", removeTodo

  addListener todoList, 'click', (e) ->
    e.preventDefault() if e.preventDefault
    # TODO

if document.addEventListener
  addListener = (el, type, listener) ->
    el.addEventListener type, listener, false
else
  addListener = (el, type, listener) ->
    el.attachEvent 'on' + type, (e) ->
      listener e || event
