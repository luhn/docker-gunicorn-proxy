# gunicorn-proxy

It is heavily recommended to [put gunicorn behind a reverse proxy](https://docs.gunicorn.org/en/stable/deploy.html) such as nginx.
Doing so can be a lot of extra work and boilerplate, especially in a containerized environment.

`gunicorn-proxy` is a Docker turnkey reverse proxy for gunicorn.
To use it you only need to set one piece of configuration—The hostname and port of your gunicorn server.
Additional (and optional) configuration is all set via environment variables for convenience.

Although this project is entitled `gunicorn-proxy`, there are no gunicorn-specific features and this will most likely be effective for any HTTP-speaking application server.

## Getting Started

This project is available from Docker Hub as [luhn/gunicorn-proxy:0.4](https://hub.docker.com/r/luhn/gunicorn-proxy).

Running this container requires a single argument:  The hostname and port of your application server.
The container will run a reverse proxy on port 8000 and forward all requests to your application server.

For example, the docker command might look like this:

```bash
docker run -p 8000:8000 --link gunicorn luhn/gunicorn-proxy gunicorn:8080
```

## Configuration

The proxy is configured via environment variables.

* `MAX_CONNECTIONS` — The maximum number of simultaneous connections.
  Defaults to 10000.
* `MAX_BODY_SIZE` — The maximum size of the request body.
  Defaults to `1m`.
* `SCHEME` — If set, will set the `X-Forwarded-Proto` header.
* `SSL_KEY` — A path to an SSL key file.
  If set, SSL will be used.
* `SSL_CRT` — A path to an SSL certificate.
  Must be set if `SSL_KEY` is set.
* `AUTO_SSL` — If set, a self-signed SSL certificate will be generated and used.
* `LOG` — A location to write request logs to.
  See below for further documentation on logging.

Headers can be added to the response by setting environment variables prefixed with `HEADER_`.
Underscores in the variable name will be replaced with hyphens.
This feature is useful for setting HTTP Strict Transport Security, Content Security Policies, etc.
For example, `HEADER_STRICT_TRANSPORT_SECURITY=max-age=3153600` will result in `STRICT-TRANSPORT-SECURITY: max-age=3153600` in the response.

## SSL

If `SSL_KEY` is set, HAProxy will serve content over HTTPS.
The configuration is taken from the [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/#server=nginx&version=1.17.7&config=intermediate&openssl=1.1.1d&guideline=5.4).

If `AUTO_SSL` is set, a self-signed certificate will be generated.
This can be useful if your container is behind another load balancer, such as AWS Application Load Balancer.
ALB does not validate the certificate on the backends; AWS claims that data sent over a VPC cannot be spoofed or MITM'd.

## Logging

You can enable per-request logging by setting `LOG` to `stdout` or a file path.
You can also send logs to a syslog server with `syslog:server=address`.  ([docs](https://nginx.org/en/docs/syslog.html))

Request logs are outputted as JSON objects with the following fields:

* `ip` — The IP address of the client.
* `method` — The request method.
* `uri` — The request URI, including query parameters.
* `status` — The HTTP status of the response.
* `processing_time` — The time in seconds that gunicorn took to response.
* `request_time` — The time in seconds to process the request from start to finish.
* `request_size` — The size in bytes of the request.
* `time` — The request time in ISO 8601 format.

All field values are strings.
