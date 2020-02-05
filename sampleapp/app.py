from time import sleep


def application(environ, start_response):
    path = environ['PATH_INFO'].strip('/')
    if path == 'healthcheck':
        status = '200 OK'
        headers = [('Content-type', 'text/plain')]
        start_response(status, headers)
        return [b"OK\n"]
    elif path:
        try:
            sleep_time = float(path)
        except ValueError:
            raise ValueError('Path must be an integer or float.')
        sleep(sleep_time)
    status = '200 OK'
    headers = [('Content-type', 'text/plain')]
    start_response(status, headers)
    return [b"Hello Gunicorn!\n"]
