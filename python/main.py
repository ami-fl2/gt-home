from http.server import BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs


def fibonacci(n: int):
    """Return the first `n` Fibonacci numbers."""
    # TODO: Fill this function out
    pass


class GetFibs(BaseHTTPRequestHandler):
    def do_GET(self):
        query = urlparse(self.path).query
        params = parse_qs(query)

        if "n" not in params:
            self.send_response(422)
            return

        try:
            key = int(params["n"][0])
        except (IndexError, ValueError):
            self.send_response(422)

        nums = fibonacci(key)

        # convert nums from int to string list
        str_nums = [str(n) for n in nums]
        final_nums = ", ".join(str_nums)

        self.send_response(200)
        self.end_headers()
        self.wfile.write(bytes(final_nums, "UTF-8"))
        return


if __name__ == "__main__":
    from http.server import HTTPServer

    httpd = HTTPServer(("", 8000), GetFibs)
    httpd.serve_forever()
