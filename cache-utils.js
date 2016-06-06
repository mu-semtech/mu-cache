var _ = require("underscore");
var utils = require("./utils");

// Generates a key which can be used in a hash to find the
// combination of the method and the uri.
function buildRequestKey(method, uri) {
  return method + " " + uri;
}

var cacheUtils = {
  initCache: function(){
    return {};
  },

  createEntry: function(method, uri, keys, headers, data) {
    return {
      requestKey: buildRequestKey(method, uri),
      keys: keys,
      headers: headers,
      data: data
    }
  },

  update: function(cache, cacheEntry) {
    cache[cacheEntry.requestKey] = cacheEntry;
    return cache;
  },

  hit: function(cache, method, uri) {
    var requestKey = buildRequestKey(method, uri);
    return cache[requestKey];
  },

  flush: function(cache, keys) {
    //TODO: speficy short way to delete all?
    return _.omit(cache, function(e) {
      return utils.intersects(_.isEqual, e.keys, keys);
    });
  },

  filter: function(cache, keys){
  	return _.pick(cache, function(e) {
  		return utils.intersects(_.isEqual, e.keys, keys);
    });
  }
}

module.exports = cacheUtils;
