var path = require('../path')
  , objectWithOnly = path.objectWithOnly
  , objectExcept = path.objectExcept
  , specIdentifier = require('../util/speculative').identifier

exports.projectDomain = projectDomain;

function projectDomain (domain, fields, isExcept) {
  fields = Object.keys(fields);
  var projectObject = isExcept
                    ? objectExcept
                    : objectWithOnly;
  if (Array.isArray(domain)) {
    return domain.map( function (doc) {
      return projectObject(doc, fields);
    });
  }

  var out = {};
  for (var k in domain) {
    if (k === specIdentifier) continue;
    out[k] = projectObject(domain[k], fields);
  }
  return out;
}
