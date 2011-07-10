var addListener, rally;
rally = require('rally');
window.onload = function() {
  var board, close, dragData, html, id, letter, model, open, _ref;
  model = rally.model;
  board = document.getElementById('board');
  dragData = null;
  html = '';
  if (/*@cc_on!@*/0) {
    open = '<a href=# onclick="return false"';
    close = '</a>';
  } else {
    open = '<span';
    close = '</span>';
  }
  _ref = model.get('letters');
  for (id in _ref) {
    letter = _ref[id];
    html += "" + open + " draggable=true class=\"" + letter.color + " letter\" id=" + id + "\nstyle=left:" + letter.left + "px;top:" + letter.top + "px>" + letter.value + close;
  }
  board.innerHTML = html;
  addListener(board, 'selectstart', function() {
    return false;
  });
  addListener(board, 'dragstart', function(e) {
    var target;
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('Text', 'x');
    target = e.target || e.srcElement;
    dragData = {
      target: target,
      startLeft: e.clientX - target.offsetLeft,
      startTop: e.clientY - target.offsetTop
    };
    return target.style.opacity = 0.5;
  });
  addListener(board, 'dragover', function(e) {
    if (e.preventDefault) {
      e.preventDefault();
    }
    e.dataTransfer.dropEffect = 'move';
    return false;
  });
  addListener(board, 'dragend', function(e) {
    return dragData.target.style.opacity = 1;
  });
  addListener(board, 'drop', function(e) {
    var dragTarget, letterPath;
    if (e.preventDefault) {
      e.preventDefault();
    }
    dragTarget = dragData.target;
    letterPath = 'letters.' + dragTarget.id;
    model.set(letterPath + '.left', e.clientX - dragData.startLeft);
    model.set(letterPath + '.top', e.clientY - dragData.startTop);
    return dragTarget.parentNode.appendChild(dragTarget);
  });
  return model.on('set', 'letters.*.left|top', function(id, prop, value) {
    var el;
    el = document.getElementById(id);
    return el.style[prop] = value + 'px';
  });
};
if (document.addEventListener) {
  addListener = function(el, type, listener) {
    return el.addEventListener(type, listener, false);
  };
} else {
  addListener = function(el, type, listener) {
    return el.attachEvent('on' + type, function(e) {
      return listener(e || event);
    });
  };
}