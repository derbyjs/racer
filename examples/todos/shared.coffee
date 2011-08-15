exports.todoHtml = ({id, text, completed}) ->
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

