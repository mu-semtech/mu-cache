var _ = require("underscore");
var utils = require("./utils");
var cacheUtils = require("./cache-utils");
var http = require("http");
var logger = require('log4js').getLogger();
var httpProxy = require("http-proxy");
var cacheBackend = setCacheBackend(process.env);
var serverPort = process.env.PORT || 5000;

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
      cache = cacheUtils.flush(cache, keys);
      writeResponseJSON(response, 200, {});
      return;
    }

    if (request.method === "GET") {
      var entries = (keys.length == 0 && cache) || cacheUtils.filter(cache, keys);
      writeResponseJSON(response, 200, entries);
      return;
    }

    writeResponseJSON(response, 405, {});
    return;
  }

  if (request.method !== "GET") {
    proxy.web(request, response, {
      target: cacheBackend
    });
    return;
  }

  //try to hit the cache
  var cacheEntry = cacheUtils.hit(cache, request.url);

  if (utils.existy(cacheEntry)) {
    logger.info("Cache hit for " + request.url);
    writeResponse(response, 200, cacheEntry.data, cacheEntry.headers);
    return;
  }

  //forward request to proxy
  proxy.web(request, response, {
    target: cacheBackend
  });
});

//intercept and eventually manipulate response from target
proxy.on("proxyRes", function(backendResponse, request, response) {
  
  if(backendResponse.statusCode !== 200){
    return;
  }

  if (backendResponse.headers["clear-keys"]) {
    cache = cacheUtils.flush(cache, utils.arrify(JSON.parse(backendResponse.headers["clear-keys"]))); //ok to crash?
  }

  if (backendResponse.headers["cache-keys"]) {
    stripBackendResponse(backendResponse)
    .then(function(stripped) {
        var entry = cacheUtils.createEntry(request.url, stripped.keys, stripped.headers, stripped.data);
        cache = cacheUtils.update(cache, entry);
    });
  }
});

proxy.on("error", function(error, request, response) {
  logger.error(error.message);
  writeResponseJSON(response, 502, {});
});

logger.info("listening on port " + serverPort);
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
    var keys = utils.arrify(JSON.parse(response.headers["cache-keys"]));
    delete response.headers["cache-keys"];
    delete response.headers["clear-keys"];

    var data = '';

    response.on("data", function(chunk) {
       data += chunk;
    });

    response.on("end", function() {
      resolve({
        "data": data,
        "headers": response.headers, 
        "keys":  keys
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
    throw("Please provide url to  environment variable CACHE_BACKEND!")
  }
  return env.CACHE_BACKEND;
}
