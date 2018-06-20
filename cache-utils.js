var _ = require("underscore");
var utils = require("./utils");

// Generates a key which can be used in a hash to find the
// combination of the method and the uri.
function buildRequestKey(method, uri) {
  return method + " " + uri;
}

function sortObject( source ) {
  if( source instanceof Array ){
    return source.map( function(item) { return sortObject(item); } );
  } else if( source instanceof Object ){
    var sortedObject = {};
    var keys = Object.keys(source || {});
    if(!process.env.SKIP_KEY_SORTING) {
        keys = keys.sort();
    }
    keys.map( function(key) {
      sortedObject[key] = sortObject(source[key]);
    } );
    return sortedObject;
  } else {
    return source;
  }
}

var cacheUtils = {
  initCache: function() {
    return { requests: {}, keys: {} };
  },

  clear: function( cache ) {
    cache.requests = {};
    cache.keys = {};
  },

  size: function( cache ) {
    return { requests: Object.keys(cache.requests).length,
             keys: Object.keys(cache.keys).length };
  },

  objectCacheKey: function( source ) {
    return JSON.stringify( sortObject( source ) );
  },

  createEntry: function(request, keys, responseHeaders, responseBody) {
    var group;
    if (responseHeaders['mu-auth-allowed-groups'])
      group = responseHeaders['mu-auth-allowed-groups']; // the backend returned auth groups
    else if (request.headers['mu-auth-allowed-groups'])
      group = request.headers['mu-auth-allowed-groups']; // fallback to the auth groups of the request
    else
      group = 'PUBLIC'; // nothing known about auth groups

    return {
      requestKey: buildRequestKey(request.method, request.url),
      group: group,
      keys: keys.map( function(k) { return cacheUtils.objectCacheKey( k ); } ),
      headers: responseHeaders,
      data: responseBody
    };
  },

  update: function(cache, cacheEntry, logger) {
    if (!cache.requests[cacheEntry.requestKey])
      cache.requests[cacheEntry.requestKey] = {};
    cache.requests[cacheEntry.requestKey][cacheEntry.group] = cacheEntry;

    logger.debug("updating keys: " + JSON.stringify(cacheEntry.keys));

    cacheEntry.keys.forEach( function(key) {
      if(!cache.keys[key])
        cache.keys[key] = {};
      if(!cache.keys[key][cacheEntry.requestKey])
        cache.keys[key][cacheEntry.requestKey] = {};

      cache.keys[key][cacheEntry.requestKey][cacheEntry.group] = true;
    });

    logger.debug("done updating");

    return cache;
  },

  hit: function(cache, method, uri, headers) {
    var requestKey = buildRequestKey(method, uri);
    var group = headers['mu-auth-allowed-groups'] || 'PUBLIC';
    return cache.requests[requestKey] ? cache.requests[requestKey][group] : null;
  },

  flush: function(cache, keys, logger) {
    var self = this;
    // we clear the keys for each key using the index
    logger.debug("Flushing keys: " + JSON.stringify(keys));
    keys.forEach( function(key) {
      Object.keys( cache.keys[key] || {} ).forEach( function( requestKey ) {
        Object.keys( cache.keys[key][requestKey] || {} ).forEach( function( group ) {
          self.cleanupRequestKeys(cache, requestKey, group, logger);
        });
      });
      delete cache.keys[key];
    } );
    logger.debug("done flushing");
  },

  // remove the keys of this entry from the interested keys
  // but only if we are interested in preserving memory
  cleanupRequestKeys: function(cache, requestKey, group, logger) {
    var currentEntry = cache.requests[requestKey][group];
    // remove the entry
    delete cache.requests[requestKey];

    var chance = Math.random();
    logger.debug("clear cache? " + process.env.SLOPPINESS_RATING + " clean: " + chance);
    if ((typeof process.env.SLOPPINESS_RATING === 'undefined') || (chance > process.env.SLOPPINESS_RATING)) {

      logger.debug("Removing cached entry: " + JSON.stringify(currentEntry));
      currentEntry.keys.forEach( function( keyToRemove ) {
        logger.debug("Removing cached content: " + JSON.stringify(keyToRemove));
        delete cache.keys[keyToRemove][currentEntry.requestKey];
      } );
    }
  },

  filter: function(cache, keys){
    var returnedRequestKeys = {};

    keys.forEach( function(key) {
      cache.keys[key].forEach( function(requestKey) {
        returnedRequestKeys[requestKey] = true;
      } );
    } );

    return Object.keys(returnedRequestKeys).map( function(key) {
      return cache.requests[key];
    } );
  }
}

module.exports = cacheUtils;
