exports.sliceDomain = sliceDomain;

function sliceDomain (list, skip, limit) {
  if (typeof skip === 'undefined') skip = 0;
  return list.slice(skip, skip + limit);
}
