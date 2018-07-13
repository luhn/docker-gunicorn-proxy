# docker-gunicorn-proxy

An nginx reverse proxy to put in front of a gunicorn, configured via
environment variables.

## Nice defaults

* gzip compression is enabled.
* Source IP will be taken from X-Forwarded-For
* Logs requests as JSON into stdout

## Logging

This container will output JSON logs into stdout.  Log fields are:

* `ip`
* `method`
* `uri`
* `status`
* `processing_time`
* `user_agent`
* `referer`

## Configuring

nginx can be configured by passing the following environment variables:

* `SERVER` — The hostname of the gunicorn container.  Required.
* `SCHEME` — `http` or `https`.  Defaults to `https`.
