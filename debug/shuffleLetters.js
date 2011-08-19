// Run this in firefox after you go into offline mode

for (var i = 0, l = 26*5; i < l; i++) {
  var letter = document.getElementById(i)
    , drag = document.createEvent('DragEvents');
  drag.initDragEvent('dragstart', true, true, window, 0, 0, 0, parseInt(letter.style.left, 10), parseInt(letter.style.top, 10), false, false, false, false, 0, null, {setData: function () {} });
  letter.dispatchEvent(drag);

  var drop = document.createEvent('DragEvents'); 
  drop.initDragEvent('drop', true, true, window, 0, 0, 0, Math.random() * 700, Math.random() * 400, false, false, false, false, 0, null, {})
  letter.dispatchEvent(drop);

  var dragend = document.createEvent('DragEvents');
  dragend.initEvent('dragend', true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
  letter.dispatchEvent(dragend);
}
