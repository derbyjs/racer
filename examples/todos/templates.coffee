exports.page = ({todos, bundle} = {}) ->
  listHtml = (exports.todo todo for todo in todos || []).join('')
  # Escape bundle for use in an HTML attribute in single quotes, since
  # JSON will have lots of double quotes
  bundle = JSON.stringify(bundle).replace /'/g, '&#39;'
  """
  <!DOCTYPE html>
  <title>Todos</title>
  <link rel=stylesheet href=style.css>
  <body>
  <div id=overlay></div>
  <!-- calling via timeout keeps the page from redirecting if an error is thrown -->
  <form id=head onsubmit="setTimeout(todos.addTodo, 0);return false">
    <h1>Todos</h1>
    <div id=add><div id=add-input><input id=new-todo></div><input id=add-button type=submit value=Add></div>
  </form>
  <div id=dragbox></div>
  <div id=content><ul id=todos>#{listHtml}</ul></div>
  <script async src=/script.js onload='require("racer").init(#{bundle})'></script>
  """

exports.todo = ({id, text, completed} = {}) ->
  if completed
    completed = 'completed'
    checked = 'checked'
  else
    completed = ''
    checked = ''
  """<li id=#{id} class=#{completed}><table width=100%><tr>
  <td class=handle width=0><td width=100%><div class=todo>
    <label><input id=check#{id} type=checkbox #{checked} onchange=todos.check(this,#{id})><i></i></label>
    <div id=text#{id} data-id=#{id} contenteditable=true>#{text}</div>
  </div>
  <td width=0><button class=delete onclick=todos.del(#{id})>Delete</button></table>"""
