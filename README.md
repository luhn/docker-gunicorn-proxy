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
* `RATE_LIMIT` — A rate limit to enforce.  e.g., `10r/s`.  Enforced per IP
  address.  See https://nginx.org/en/docs/http/ngx_http_limit_req_module.html
  for more details.
* `RATE_LIMIT_SIZE` — The zone size.  Defaults to `10m`.
* `RATE_LIMIT_BURST` — Sets the `burst` parameter.
* `RATE_LIMIT_DELAY` — If set, sets the `nodelay` parameter.

Headers can be added to the response by setting environment variables prefixed
with `HEADER_`.  Underscores in the variable name will be replaced with
hyphens.  This feature is useful for setting HTTP Strict Transport Security,
Content Security Policies, etc.  For example,
`HEADER_STRICT_TRANSPORT_SECURITY=max-age=3153600` will result in
`STRICT-TRANSPORT-SECURITY: max-age=3153600` in the response.
