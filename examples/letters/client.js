var board, doc, dragData;
doc = document;
board = doc.getElementById('board');
dragData = null;
board.addEventListener('dragstart', function(e) {
  var dt;
  dt = e.dataTransfer;
  dt.effectAllowed = 'move';
  dt.dropEffect = 'move';
  dt.setData('text', 0);
  dragData = {
    target: e.target,
    offsetX: e.offsetX,
    offsetY: e.offsetY
  };
  return e.target.style.opacity = 0.5;
});
board.addEventListener('dragover', function(e) {
  return e.preventDefault();
});
board.addEventListener('dragend', function(e) {
  return dragData.target.style.opacity = 1;
});
board.addEventListener('drop', function(e) {
  var dragTarget, target, x, y;
  e.preventDefault();
  x = e.offsetX - dragData.offsetX;
  y = e.offsetY - dragData.offsetY;
  if ((target = e.target) !== board) {
    if (target.parentNode !== board) {
      target = target.parentNode;
    }
    x += target.offsetLeft;
    y += target.offsetTop;
  }
  dragTarget = dragData.target;
  dragTarget.style.left = x + 'px';
  dragTarget.style.top = y + 'px';
  return dragTarget.parentNode.appendChild(dragTarget);
});