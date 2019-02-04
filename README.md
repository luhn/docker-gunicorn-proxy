# docker-gunicorn-proxy

It is highly recommended to put a reverse proxy in front of Gunicorn.  This
project provides a turnkey reverse proxy for gunicorn in a Docker environment.

The Gunicorn docs recommend nginx, but this project use HAProxy for the more
robust proxy features.  Notably, HAProxy offers request queuing, which we use
for load shedding during times of excessive load.  (nginx does have queuing
functionality, but it's only available in the commercial version.)

## Getting Started

This project is available from Docker Hub as
[luhn/gunicorn-proxy:0.2](https://hub.docker.com/r/luhn/gunicorn-proxy).

Get your gunicorn running in a container.  Then run this project, using the
`SERVER` environment variable to point it at your gunicorn container.  For
example, this might look like:

```bash
docker run --link gunicorn -e "SERVER=gunicorn:8080" -e "CONCURRENCY=4" luhn/gunicorn-proxy
```

Set `CONCURRENCY` to the number of gunicorn workers you have.

## Configuration

The proxy is configured via environment variables.

* `SERVER` — The hostname of the gunicorn container.  Required.
* `CONCURRENCY` — The number of concurrent requests to allow through to
  gunicorn.  It's recommended to set this equal to the number of gunicorn
  workers.
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

## Healthchecks

Requests matching `HEALTHCHECK_PATH` skip the queue.  This allows healthchecks
to continue succeeding even when the proxy is load shedding, as long as
gunicorn is still processing requests.

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

