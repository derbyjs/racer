rally = require 'rally'

rally.onload = ->
  model = rally.model

  todoList = document.getElementById 'todos'

  addTodo = (index) ->
    nextId = model.get 'todos.nextId'
    model.set 'todos.nextId', ++nextId
    model.set "todos.#{nextId}", { text: '' }
    model.insertAfter "groups.#{groupId}.todos", index-1, model.ref('todos', nextId)
  removeTodo = (id) ->
    model.del 'todos.' + id
  removeTodoAt = (index) ->
    model.remove "groups.#{groupId}", index
  updateTodo = (id, text) ->
    model.set "todos.#{id}.text", text

  addTodoToUi = (id, index, member) ->
    todoList.innerHtml

  removeTodo = (todoId) ->
    model.del "todos.#{todoId}"

  model.on 'insertAfter', "groups.#{groupId}.todos", addTodo
  model.on 'remove', "groups.#{groupId}.todos", removeTodo

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
