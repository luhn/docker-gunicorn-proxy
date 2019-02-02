# docker-gunicorn-proxy

An reverse proxy to put in front of a gunicorn, configured via environment
variables.

The proxy will queue requests and return a 503 if they've queued too long.
This load shedding allows the server to continue to serve some requests within
a reasonable time during periods of high load.

## Configuration

The proxy is configured via environment variables.

* `SERVER` — The hostname of the gunicorn container.  Required.
* `CONCURRENCY` — Should match the number of gunicorn workers or threads.
  Required.
* `QUEUE_TIMEOUT` — How long requests will wait for a gunicorn worker before
  timing out.  Can be a number in milliseconds or suffixed with `s`, `m`, etc.
  Defaults to three seconds.
* `SCHEME` — If set, will set the `X-Forwarded-Proto` header.
* `HEALTHCHECK_PATH` — The path for the healthcheck endpoint.  Defaults to
  `/healthcheck`.

## Healthchecks

Requests matching `HEALTHCHECK_PATH` skip the queue.  This allows healthchecks
to continue succeeding even when the proxy is load shedding, as long as
gunicorn is still processing requests.
