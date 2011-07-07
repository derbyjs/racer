var addListener;
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
window.onload = function() {
  var board, close, col, colors, dragData, html, id, letter, letters, open, row;
  board = document.getElementById('board');
  dragData = null;
  colors = ['red', 'yellow', 'blue', 'orange', 'green'];
  letters = {};
  for (row = 0; row <= 4; row++) {
    for (col = 0; col <= 25; col++) {
      letters[row * 26 + col] = {
        color: colors[row],
        value: String.fromCharCode(65 + col),
        x: col * 24 + 72,
        y: row * 32 + 8
      };
    }
  }
  html = '';
  if (/*@cc_on!@*/0) {
    open = '<a href=# onclick="return false"';
    close = '</a>';
  } else {
    open = '<span';
    close = '</span>';
  }
  for (id in letters) {
    letter = letters[id];
    html += "" + open + " draggable=true class=\"" + letter.color + " letter\" id=" + id + "\nstyle=left:" + letter.x + "px;top:" + letter.y + "px>" + letter.value + close;
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
      startX: e.clientX - target.offsetLeft,
      startY: e.clientY - target.offsetTop
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
  return addListener(board, 'drop', function(e) {
    var dragTarget;
    if (e.preventDefault) {
      e.preventDefault();
    }
    dragTarget = dragData.target;
    dragTarget.style.left = e.clientX - dragData.startX + 'px';
    dragTarget.style.top = e.clientY - dragData.startY + 'px';
    return dragTarget.parentNode.appendChild(dragTarget);
  });
};