using Mux
using Test
using Lazy
using HTTP

@test Mux.notfound()(d())[:status] == 404

# Test basic server
@app test = (
  Mux.defaults,
  page("/",respond("<h1>Hello World!</h1>")),
  page("/about", respond("<h1>Boo!</h1>")),
  page("/user/:user", req -> "<h1>Hello, $(req[:params][:user])!</h1>"),
  Mux.notfound())
serve(test)
@test String(HTTP.get("http://localhost:8000").body) ==
            "<h1>Hello World!</h1>"
@test String(HTTP.get("http://localhost:8000/about").body) ==
            "<h1>Boo!</h1>"
@test String(HTTP.get("http://localhost:8000/user/julia").body) ==
            "<h1>Hello, julia!</h1>"

# Issue #68
@test Mux.fileheaders("foo.css")["Content-Type"] == "text/css"
@test Mux.fileheaders("foo.html")["Content-Type"] == "text/html"
@test Mux.fileheaders("foo.js")["Content-Type"] == "application/javascript"

function f()
  @app foo = (Mux.defaults)
end

@test f() == nothing
