require.registerExtension '.js', (js) ->
  js.replace /^ *\/\/debug: */gm, ''
