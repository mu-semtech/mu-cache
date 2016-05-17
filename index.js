var _ = require("underscore");
var http = require("http");
var logger = require('log4js').getLogger();
var httpProxy = require("http-proxy");
var cacheBackend = process.env.CACHE_BACKEND; //validate backend url!
var serverPort = process.env.PORT || 5000;

var cache = [];
var proxy = httpProxy.createProxyServer({});
var server = http.createServer(function(request, response) {

  if (isKeysRoute(request)) {
    var keys = parseKeysQuery(unescape(request.url)); //needs catching error with json parse

    if (request.method === "DELETE") {
      cache = flushCache(cache, keys);
      writeResponse(response, 200);
      return;
    }

    if (request.method === "GET") {
      var entries = (keys.length == 0 && cache) || cache.filter(function(e) {
        return intersects(_.isEqual, e.keys, keys);
      });
      writeResponse(response, 200, entries);
      return;
    }

    writeResponse(response, 405);
    return;
  }

  if (request.method !== "GET") {
    proxy.web(request, response, {
      target: cacheBackend
    });
    return;
  }

  //make sure client gets most up to date information if he requests so
  if (request.headers["clear-keys"]) {
    var keysToClear = arrify(JSON.parse(request.headers["clear-keys"]));
    cache = flushCache(cache, keysToClear);
  }

  //now let's try to hit the cache
  var cacheEntry = hitCache(cache, request.url);

  if (existy(cacheEntry)) {
    logger.info("Cache hit for " + request.url);
    writeResponse(response, 200, cacheEntry.response.data, cacheEntry.response.headers);
    return;
  }

  //forward request to proxy
  proxy.web(request, response, {
    target: cacheBackend
  });
});

//intercept and eventually store response from backend
proxy.on("proxyRes", function(proxyResponse, request, response) {
  if (request.headers["cache-keys"] && proxyResponse.statusCode == 200) {
    pushCacheStream(cache, request.url, arrify(JSON.parse(request.headers["cache-keys"])), proxyResponse);
  }
});

proxy.on("error", function(error, request, response) {
  logger.error(error.message);
  writeResponse(response, 502);
});

logger.info("listening on port " + serverPort);
server.listen(serverPort);

/********************************************************************************************************************
 * helpers
 ********************************************************************************************************************/
function parseKeysQuery(query) {
  var data = query.split('/keys/');
  return (data.length == 2 && !_.every(data, _.isEmpty)) ? arrify(JSON.parse(data[1])) : [];
}

function isKeysRoute(request) {
  //matches /keys /keys/ /keys/something
  return (unescape(request.url).match(/^\/keys\/?$|^\/keys\/[\S\s]*$/) && true) || false;
}

function pushCacheStream(cache, requestUrl, requestKeys, responseStream) {
  var cacheEntry = {
    query: requestUrl,
    keys: requestKeys,
    response: {
      headers: responseStream.headers,
      data: ''
    }
  };

  responseStream.on("data", function(chunk) {
    cacheEntry.response.data += chunk;
  })

  responseStream.on("end", function() {
    cache.push(cacheEntry);
  });
}

function hitCache(cache, query) {
  return cache.find(function(element) {
    return element.query === query;
  })
}

function flushCache(cache, keys) {
  //TODO: speficy short way to delete all?
  return cache.filter(function(e) {
    return !intersects(_.isEqual, e.keys, keys);
  });
}

function intersects(comparator, array1, array2) {
  return existy(array1.find(function(element1) {
    return existy(array2.find(function(element2) {
      return comparator(element1, element2);
    }));
  }));
}

function existy(data) {
  return !(_.isNaN(data) || _.isNull(data) || _.isUndefined(data));
}

function arrify(data) {
  return (data instanceof Array) ? data : [data];
}

function writeResponse(response, statusCode, body, headers) {
  var headers = (_.isEmpty(headers)) ? {
    "Content-Type": "application/json"
  } : headers;
  response.writeHead(statusCode, headers);
  var str = (body || {}) instanceof Object ? JSON.stringify(body || {}) : body; //needs refinment
  response.end(str);
}
