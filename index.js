// monkey patch http parser so you can have headers longer than 80k
// see http://stackoverflow.com/questions/24167656/nodejs-max-header-size-in-http-request
// in this case, headers this large can happen because for instance the resources
// service can invalidate a large amount of cache keys
process.binding('http_parser').HTTPParser = require('http-parser-js').HTTPParser;
var maxHeaderSize = process.env.MAX_HEADER_SIZE || 64 * 1024 * 1024; // 64MB instead of 80kb
require('http-parser-js').HTTPParser.maxHeaderSize = maxHeaderSize;

var _ = require("underscore");
var utils = require("./utils");
var cacheUtils = require("./cache-utils");
var http = require("http");
var logger = require('log4js').getLogger();
logger.level = process.env.DEBUG ? 'debug' : 'info';
var httpProxy = require("http-proxy");
var cacheBackend = setCacheBackend(process.env);
var serverPort = process.env.PORT || 80;

var cache = cacheUtils.initCache();
var proxy = httpProxy.createProxyServer({});
var server = http.createServer(function(request, response) {

  if (isKeysRoute(request)) {
    var keys;
    try {
      keys = parseKeysQuery(unescape(request.url));
    } catch (e) {
      return writeResponseJSON(response, 400, {
        "msg":"Errors parsing keys"
      });
    }

    if (request.method === "DELETE") {
      cacheUtils.flush(cache, keys, logger);
      return writeResponseJSON(response, 200, {});
    }

    if (request.method === "GET") {
      var entries = (keys.length == 0 && cache) || cacheUtils.filter(cache, keys);
      return writeResponseJSON(response, 200, entries);
    }

    return writeResponseJSON(response, 405, {});
  } else if (request.method === "POST" && request.url == "/clear") {
    cacheUtils.clear(cache);
    logger.info("Cleared cache");
    return writeResponseJSON(response, 200, {"status": "ok"});
  } else if (request.method === "GET" && request.url == "/size") {
    var size = cacheUtils.size(cache);
    logger.info("Counted cache");
    return writeResponseJSON(response, 200, size);
  }

  // Try to hit the cache
  // logger.info("Trying to hit cache with " + request.method + " " + request.url);
  // logger.info("Current cache: " + JSON.stringify( cache ));
  var cacheEntry = cacheUtils.hit(cache, request.method, request.url, request.headers);

  var cacheKey = request.method + " " + request.url + " " + request.headers['mu-authorization-groups'];
  if (utils.existy(cacheEntry)) {
    logger.info("Cache hit for " + cacheKey);
    return writeResponse(response, 200, cacheEntry.data, cacheEntry.headers);
  }

  logger.info("Cache miss for " + cacheKey);
  // Forward request to proxy
  return proxy.web(request, response, {
    target: cacheBackend
  });
});

// Add error message on caught exception
var doProxy = function(event, handler) {
  try {
    proxy.on(event,handler);
  } catch (e) {
    var message = e;
    if(message && message.message) {
      message = message.message;
    }
    logger.error(message);
  }
};

var normalizeKeys = function(headerContent){
  return JSON.parse(headerContent).map( function(k) { return cacheUtils.objectCacheKey( k ); } );
};

// Intercept and manipulate response from target
doProxy("proxyRes", function(backendResponse, request, response) {
  var cleared = backendResponse.headers["clear-keys"];
  var cached = backendResponse.headers["cache-keys"];

  stripBackendResponse(backendResponse).then((stripped) => {
    if (cleared) {
      var clearKeys = normalizeKeys( cleared );
      logger.debug("Clearing keys " + JSON.stringify( clearKeys ));
      cacheUtils.flush(cache, utils.arrify(clearKeys), logger); //ok to crash?
    }

    if (cached) {
      var cacheKeys = utils.arrify(JSON.parse(cached));
      logger.debug("Caching keys " + JSON.stringify( cacheKeys ));
      var entry = cacheUtils.createEntry(request, cacheKeys, stripped.headers, stripped.data);
      cacheUtils.update(cache, entry, logger);
    }
  }, function(error){
    logger.error(error);
  });
});

doProxy("error", function(error, request, response) {
  logger.error(error.message);
  writeResponseJSON(response, 502, {});
});

logger.info("Listening on port " + serverPort);
server.listen(serverPort);

/********************************************************************************************************************
 * helpers
 ********************************************************************************************************************/
function parseKeysQuery(query) {
  var data = query.split('/keys/');
  return (data.length == 2 && !_.every(data, _.isEmpty)) ? utils.arrify(JSON.parse(data[1])) : [];
}

function isKeysRoute(request) {
  //matches /keys /keys/ /keys/something
  return (unescape(request.url).match(/^\/keys\/?$|^\/keys\/[\S\s]*$/) && true) || false;
}

function stripBackendResponse(response) {
  return new Promise(function(resolve, reject) {
    delete response.headers["cache-keys"];
    delete response.headers["clear-keys"];

    var data = '';

    response.on("data", function(chunk) {
       data += chunk;
    });

    response.on("end", function() {
      resolve({
        "data": data,
        "headers": response.headers
      });
    });
  });
}

function writeResponseJSON(response, statusCode, body) {
  return writeResponse(response, statusCode, JSON.stringify(body), {
    "Content-Type": "application/json"
  });
}

function writeResponse(response, statusCode, body, headers) {
  response.useChunkedEncodingByDefault = false;
  response.writeHead(statusCode, headers);
  return response.end(body);
}

function setCacheBackend(env){
  if(!env.CACHE_BACKEND){
    throw("Please provide url to  environment variable CACHE_BACKEND!");
  }
  return env.CACHE_BACKEND;
}
