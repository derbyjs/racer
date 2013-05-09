exports.page = ({groupName, todos, bundle} = {}) ->
  listHtml = (exports.todo todo for todo in todos || []).join('')
  # Escape bundle for use in an HTML attribute in single quotes, since
  # JSON will have lots of double quotes
  bundle = JSON.stringify(bundle).replace /'/g, '&#39;'
  """
  <!DOCTYPE html>
  <meta charset="utf-8">
  <title>Racer todos - #{groupName}</title>
  <link rel="stylesheet" href="style.css">
  <form id="head" onsubmit="return false">
    <h1>Todos</h1>
    <div id="add">
      <div id="add-input"><input id="new-todo"></div>
      <input id="add-button" type="submit" value="Add">
    </div>
  </form>
  <div id="dragbox"></div>
  <form id="content" autocomplete="off">
    <ul id="todos">#{listHtml}</ul>
  </form>
  <script async src="/script.js" onload='require("racer").init(#{bundle})'></script>
  """

exports.todo = ({id, text, completed} = {}) ->
  if completed
    completed = 'completed'
    checked = 'checked'
  else
    completed = ''
    checked = ''
  """
  <li id="#{id}" class="#{completed}">
    <table width="100%">
      <td class="handle" width="0"></td>
      <td width="100%">
        <div class="todo">
          <label><input type="checkbox" #{checked}><i></i></label>
          <div class="text" contenteditable>#{text}</div>
        </div>
      </td>
      <td width="0"><button type="button" class="delete">Delete</button></td>
    </table>
  </li>
  """
