# gunicorn-proxy

`gunicorn-proxy` is a turnkey reverse proxy for gunicorn in a Docker
environment.

As well as being simple to set up, this has the additional benefit of load
shedding.  Under high load, the proxy will return 503 errors for a portion of
requests.  This allows the application to maintain acceptable response times
for some requests and fail quickly for others.  The proxy also allows health
checks to skip the queue, so health checks will continue to succeed as long as
the application continues to serve requests.

Although this project is entitled `gunicorn-proxy`, there are few
gunicorn-specific features and this will most likely be effective for any
HTTP-speaking application server.

## Getting Started

This project is available from Docker Hub as
[luhn/gunicorn-proxy:0.3](https://hub.docker.com/r/luhn/gunicorn-proxy).

Running this container requires two arguments.  The first is the hostname and
port of your gunicorn container.  The second is how many requests should be
proxied concurrently to gunicorn.  This is best set to the number of gunicorn
workers.

For example, the docker command might look like this:

```bash
docker run --link gunicorn luhn/gunicorn-proxy gunicorn:8080 3
```

## Configuration

The proxy is configured via environment variables.

* `MAX_CONNECTIONS` — The number of simultaneous connections HAProxy will
  accept.  Defaults to 2000.
* `SYSLOG_SERVER` — A syslog server to output logs to.  Defaults to
  `localhost`.
* `QUEUE_TIMEOUT` — How long requests will wait for a gunicorn worker before
  timing out.  Can be a number in milliseconds or suffixed with `s`, `m`, etc.
  Defaults to three seconds.
* `SCHEME` — If set, will set the `X-Forwarded-Proto` header.
* `HEALTHCHECK_PATH` — The path for the healthcheck endpoint.  Defaults to
  `/healthcheck`.

Headers can be added to the response by setting environment variables prefixed
with `HEADER_`.  Underscores in the variable name will be replaced with
hyphens.  This feature is useful for setting HTTP Strict Transport Security,
Content Security Policies, etc.  For example,
`HEADER_STRICT_TRANSPORT_SECURITY=max-age=3153600` will result in
`STRICT-TRANSPORT-SECURITY: max-age=3153600` in the response.

## Queuing

The proxy will queue requests and return a 503 if they've queued too long.
This load shedding allows the server to continue to serve some requests within
a reasonable time during periods of excessive load.

Requests matching `HEALTHCHECK_PATH` skip the queue.  This allows healthchecks
to continue succeeding even when the proxy is load shedding, as long as
gunicorn is still processing requests.

`MAX_CONNECTIONS` should be set to a number greater than `QUEUE_TIMEOUT`
multiplied by the maximum number requests per second your application can
serve.  Otherwise HAProxy may start rejecting new connections before the queue
fills up, negating the benefits of having one.  `MAX_CONNECTIONS` defaults to
2000, which should be great enough for most applications.

## Logging

Technically `SYSLOG_SERVER` is not required, as by default logs will be routed
to localhost.  However, this probably won't be particularly useful because the
logs will be lost to the void unless you're running in Docker's host network
mode.  The standard Docker practice of stdout unfortunately isn't achievable
with HAProxy without running syslog in the container.

HAProxy's default log format is overridden and set to:

```
%HM %HU %ST %TR/%Tw/%Tr/%Ta %U
```

This translates to:

```
[verb] [path+query] [status] [read time]/[queue time]/[processing time]/[total time] [request size]
```

