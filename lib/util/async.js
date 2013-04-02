module.exports = {
  finishAfter: finishAfter
};

function finishAfter(count, callback) {
  if (!callback) callback = function (err) { if (err) throw err; };
  if (!count || count === 1) return callback;
  var err;
  return function (_err) {
    err || (err = _err);
    --count || callback(err);
  };
}
