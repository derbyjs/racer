require('racer').ready(function(model) {
  // model is exposed on the window for convenience in debugging. There is no
  // need to do this normally
  window.model = model;
  // model.at() scopes all model operations underneath a particular path
  setup(model.at('_page.room'));
});

function setup(model) {
  var pad = document.getElementById('pad');

  function getValue() {
    // IE and Opera replace \n with \r\n
    return pad.value.replace(/\r\n/g, '\n');
  }

  model.on('change', function(value) {
    pad.value = value || '';
  });

  model.on('stringInsert', function(index, text, passed) {
    if (passed.local) return;
    function transformCursor(cursor) {
      return (index < cursor) ? cursor + text.length : cursor;
    }
    var previous = getValue();
    var newText = previous.slice(0, index) + text + previous.slice(index);
    replaceText(pad, newText, transformCursor);
    if (pad.value !== model.get()) debugger;
  });

  model.on('stringRemove', function(index, howMany, passed) {
    if (passed.local) return;
    function transformCursor(cursor) {
      return (index < cursor) ? Math.max(index, cursor - howMany) : cursor;
    }
    var previous = getValue();
    var newText = previous.slice(0, index) + previous.slice(index + howMany);
    replaceText(pad, newText, transformCursor);
    if (pad.value !== model.get()) debugger;
  });

  function onInput() {
    var value = getValue();
    var previous = model.get() || '';
    if (value != previous) applyChange(model, previous, value);
    if (pad.value !== model.get()) debugger;
  }

  pad.addEventListener('input', function() {
    setTimeout(onInput, 0);
  }, false);
};

function replaceText(pad, newText, transformCursor) {
  var start = pad.selectionStart;
  var end = pad.selectionEnd;
  var scrollTop = pad.scrollTop;
  pad.value = newText;
  if (pad.scrollTop !== scrollTop) {
    pad.scrollTop = scrollTop;
  }

  if (document.activeElement === pad) {
    pad.selectionStart = transformCursor(start);
    pad.selectionEnd = transformCursor(end);
  }
}

// Create an op which converts previous -> value.
//
// This function should be called every time the text element is changed.
// Because changes are always localized, the diffing is quite easy.
//
// This algorithm is O(N), but I suspect you could speed it up somehow using
// regular expressions.
function applyChange(model, previous, value) {
  if (previous === value) return;
  var start = 0;
  while (previous.charAt(start) == value.charAt(start)) {
    start++;
  }
  var end = 0;
  while (
    previous.charAt(previous.length - 1 - end) === value.charAt(value.length - 1 - end) &&
    end + start < previous.length &&
    end + start < value.length
  ) {
    end++;
  }

  if (previous.length !== start + end) {
    var howMany = previous.length - start - end;
    model.pass({local: true}).stringRemove(start, howMany);
  }
  if (value.length !== start + end) {
    var inserted = value.slice(start, value.length - end);
    model.pass({local: true}).stringInsert(start, inserted);
  }
}
