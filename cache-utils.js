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
    if(process.env.SKIP_KEY_SORTING) {
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
  initCache: function(){
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

  createEntry: function(method, uri, keys, headers, data) {
    return {
      requestKey: buildRequestKey(method, uri),
      keys: keys.map( function(k) { return cacheUtils.objectCacheKey( k ) } ),
      headers: headers,
      data: data
    }
  },

  update: function(cache, cacheEntry) {
    cache.requests[cacheEntry.requestKey] = cacheEntry;
    cacheEntry.keys.forEach( function(key) {
      if( !cache.keys[key] ) {
        cache.keys[key] = { };
      }
      cache.keys[key][cacheEntry.requestKey] = true;
    });
    return cache;
  },

  hit: function(cache, method, uri) {
    var requestKey = buildRequestKey(method, uri);
    return cache.requests[requestKey];
  },

  flush: function(cache, keys, logger) {
    var self = this;
    // we clear the keys for each key using the index
    keys.forEach( function(key) {
      // logger.info("Flushing key: " + JSON.stringify(key));
      Object.keys( cache.keys[key] || {} ).forEach( function( entry ) {
        self.cleanupRequestKeys(cache, entry, logger);
      } );
      delete cache.keys[key];
    } );
  },

  // remove the keys of this entry from the interested keys
  // but only if we are interested in preserving memory
  cleanupRequestKeys: function(cache, entry, logger) {
    var currentEntry = cache.requests[entry];
    // remove the entry
    delete cache.requests[entry];

    var chance = Math.random();
    //logger.info("clear cache? " + process.env.SLOPPINESS_RATING + " clean: "+chance);
    if ((typeof process.env.SLOPPINESS_RATING === 'undefined') || (chance > process.env.SLOPPINESS_RATING)) {

      //logger.info("Removing cached entry: " + JSON.stringify(currentEntry));
      currentEntry.keys.forEach( function( keyToRemove ) {
        // logger.info("Removing cached content: " + JSON.stringify(keyToRemove));
        delete cache.keys[keyToRemove][currentEntry.requestKey];
      } );
    }
  },

  filter: function(cache, keys){
    var returnedRequestKeys = {};

    keys.forEach( function(key) {
      cache.keys[key].forEach( function(requestKey) {
        returnedRequestKeys[requestKeys] = true;
      } );
    } );

    return Object.keys(returnedRequestKeys).map( function(key) {
      return cache.requests[key];
    } );
  }
}

module.exports = cacheUtils;
