var racer = require('../../lib/racer');

racer.on('ready', function(model) {
  window.model = model;
  model.subscribeDoc('rooms', 'home', function(err) {
    setup(model.at('rooms.home'));
  });
});

racer.init(window.RACER_BUNDLE);

function setup(model) {
  model.setNull(null, '');
  var textarea = document.getElementsByTagName('textarea')[0];
  textarea.value = model.get();

  function getValue() {
    // IE and Opera replace \n with \r\n
    return textarea.value.replace(/\r\n/g, '\n');
  }

  model.on('stringInsert', function(index, text, isLocal) {
    if (isLocal) return;
    function transformCursor(cursor) {
      return (index < cursor) ? cursor + text.length : cursor;
    }
    var previous = getValue();
    var newText = previous.slice(0, index) + text + previous.slice(index);
    replaceText(textarea, newText, transformCursor);
  });

  model.on('stringRemove', function(index, howMany, isLocal) {
    if (isLocal) return;
    function transformCursor(cursor) {
      return (index < cursor) ? cursor - Math.min(text.length, cursor - index) : cursor;
    }
    var previous = getValue();
    var newText = previous.slice(0, index) + previous.slice(index + howMany);
    replaceText(textarea, newText, transformCursor);
  });

  function onInput() {
    var value = getValue();
    var previous = model.get();
    if (value != previous) applyChange(model, previous, value);
    if (textarea.value !== model.get()) debugger;
  }

  textarea.addEventListener('input', function() {
    setTimeout(onInput, 0);
  }, false);
};

function replaceText(textarea, newText, transformCursor) {
  var start = textarea.selectionStart;
  var end = textarea.selectionEnd;
  scrollTop = textarea.scrollTop;
  textarea.value = newText;
  if (textarea.scrollTop !== scrollTop) {
    textarea.scrollTop = scrollTop;
  }

  if (window.document.activeElement === textarea) {
    textarea.selectionStart = transformCursor(start);
    textarea.selectionEnd = transformCursor(end);
  }
  if (textarea.value !== model.get()) debugger;
}

// Create an op which converts previous -> value.
//
// This function should be called every time the text element is changed. Because changes are
// always localised, the diffing is quite easy.
//
// This algorithm is O(N), but I suspect you could speed it up somehow using regular expressions.
function applyChange(model, previous, value) {
  if (previous == value) return;
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
    model.stringRemove(null, start, howMany);
  }
  if (value.length !== start + end) {
    var inserted = value.slice(start, value.length - end);
    model.stringInsert(null, start, inserted);
  }
}
