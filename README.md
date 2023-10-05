# gunicorn-proxy

It is heavily recommended to [put gunicorn behind a reverse proxy](https://docs.gunicorn.org/en/stable/deploy.html) such as nginx.
Doing so can be a lot of extra work and boilerplate, especially in a containerized environment.

`gunicorn-proxy` is a Docker turnkey reverse proxy for gunicorn.
To use it you only need to set one piece of configuration—The hostname and port of your gunicorn server.
Additional (and optional) configuration is all set via environment variables for convenience.

Although this project is entitled `gunicorn-proxy`, there are no gunicorn-specific features and this will most likely be effective for any HTTP-speaking application server.

## Getting Started

This project is available from Docker Hub as [luhn/gunicorn-proxy:0.5](https://hub.docker.com/r/luhn/gunicorn-proxy)
and AWS ECR as [public.ecr.aws/luhn/gunicorn-proxy:0.5](https://gallery.ecr.aws/luhn/gunicorn-proxy).
You can download the source code from [github.com/luhn/docker-gunicorn-proxy](https://github.com/luhn/docker-gunicorn-proxy/).

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
* `SSL_PASSWORD_FILE` - A path to a password file used for validating certificate.
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

Logs are formatted with nginx's built-in "combined" form, which is in the form:

```
$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"
```

You can customize the log format by setting the `LOG_FORMAT` variable.
See [the docs](https://nginx.org/en/docs/http/ngx_http_log_module.html#log_format) for more details.
If you want to format the logs as JSON, you can escape the log values by setting `LOG_FORMAT_ESCAPE` to `json`.
