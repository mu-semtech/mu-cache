mu-cache
================

The mu-cache provides a distributed caching proxy for JSONAPI like resources.  The service can be placed in front of any microservice which understand the cache’s primitives.  Microservices can update the mu-cache within their standard request-response cycles or by making REST calls on the mu-cache (REST calls are still under development).

Motivation
----------
Within the mu.semte.ch framework, all state is stored in the triplestore.  This construction provides much flexibility and allows microservices to cooperate nicely.  In some cases, we can expect the triplestore to get overloaded.  In this case, caching of requests may help.

Detecting when to clear the cache on a URL-basis is near-impossible, given that the set of possible calls in a JSONAPI endpoint is non-exhaustive.  In some configurations, the set of URLs which yield a particular resource may be infinite.  Primitives for managing such a cache are needed.

Managing the cache within a specific microservice is probably not wanted as the microservice would need to communicate with its peers to indicate which items are in the cache.  Eg: if we have two mu-cl-resources containers using the same image, we could load-balance between these instances.  When one of these detects an update to the model, the other would need to clear its cache also.  A microservice which tackles caching is a primitive which could be of great help in this idiomatic situation.


API
---
The mu-cache API can be wrapped in two sections: the header-based request-response, and the direct API calls.

### Request-response
This flow is used when a proxy request is received.  It can use or update the cache upon a page request.

Logical steps:
Request for “/foo” enters cache
[YES/NO] cache searches for “/foo” in its index
 - [YES]: 
   - cache returns “/foo”
   - cache logs cache hit on console
 - [NO]: cache requests same page on “backend” service
 - [WHEN] CACHE-KEYS header present: 
  - cache stores [*cleaned] response body/headers for request “GET /foo”
  - cache parses CACHE-KEYS as JSON array
  - connects each of the keys to “/foo” in CACHE-KEY-MAP for clearing in a later stage.
 - [WHEN] CLEAR-KEYS header present: 
  - cache parses CACHE-KEYS as JSON array
  - for each key in CACHE-KEYS, remove associated pages indicated in CACHE-KEY-MAP
- Cache returns [*cleaned] response

[*cleaned] response: response from the wrapped service with the CACHE-KEYS and CLEAR-KEYS headers removed.

SETTINGS
--------
The following environment variables can be used to tweak the behavior of the cache:
- CACHE_BACKEND: the url of the backend service to cache requests for (default: `http://backend`)
- PORT: the port to host the cache service on (default: 80)
- SKIP_KEY_SORTING: do not sort keys of the cache-key objects sent from the cached service, i.e. assuming the service always sends back the keys of such cache-key objects in the same order.
*Note: setting this to true is dangerous and will result in an invalid cache if the cached service ever sends back a single cache-key object in a different order!* (default: false)
- SLOPPINESS_RATING: float representing how sloppy the cache is. The cache clears the request keys that depend on a certain cache-key only this percentage of times, randomly. This action frees up memory but makes clearing cache instances more costly. It is recommended to disable this (value of 1) or set it to a low percentage if there are many requests that can depend on a single cache key. When the sloppiness of the cache is not set, it cleans up the dependent keys every time (default: undefined).

TODO
----
- review https://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html
- intermediate mu-service does decode %20 to +
