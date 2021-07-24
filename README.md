# mu-cache

The mu-cache provides a distributed caching proxy for JSONAPI like resources.  The service can be placed in front of any microservice which understand the cache’s primitives.

## Motivation
Within the mu.semte.ch framework, all state is stored in the triplestore.  This construction provides much flexibility and allows microservices to cooperate nicely.  In some cases, we can expect the triplestore to get overloaded.  In this case, caching of requests may help.

Detecting when to clear the cache on a URL-basis is near-impossible, given that the set of possible calls in a JSONAPI endpoint is non-exhaustive.  In some configurations, the set of URLs which yield a particular resource may be infinite.  Primitives for managing such a cache are needed.

Managing the cache within a specific microservice is probably not wanted as the microservice would need to communicate with its peers to indicate which items are in the cache.  Eg: if we have two mu-cl-resources containers using the same image, we could load-balance between these instances.  When one of these detects an update to the model, the other would need to clear its cache also.  A microservice which tackles caching is a primitive which could be of great help in this idiomatic situation.

## Installation
To add mu-cache to your application stack, add the following snippet to your `docker-compose.yml`

```
services:
  cache:
    image: semtech/mu-cache:2.0.0
    links:
    - myservice:backend
```

## Supported services

Services that currently support mu-cache:
- [mu-cl-resources](https://github.com/mu-semtech/mu-cl-resources/blob/master/README.md#external-cache)

These services may need to be configured in order to enable mu-cache support. Check their README for details.

## Debugging
Debugging of cache keys is helped by following environment variables:

  - `LOG_CACHE_CLEAR_EVENT`: Store cache clear events in the database
  - `LOG_CACHE_KEYS`: Logs received cache key to a response
  - `LOG_CLEAR_KEYS`: Logs received clear keys either as a response, or explicitly received through ./mu/delta.
