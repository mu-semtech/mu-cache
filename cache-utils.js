var _ = require("underscore");
var utils = require("./utils");

var cacheUtils = {
  initCache: function(){
    return {};
  },

  createEntry: function(uri, keys, headers, data) {
    return {
      uri: uri,
      keys: keys,
      headers: headers,
      data: data
    }
  },

  update: function(cache, cacheEntry) {
    cache[cacheEntry.uri] = cacheEntry;
    return cache;
  },

  hit: function(cache, query) {
    return cache[query];
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
