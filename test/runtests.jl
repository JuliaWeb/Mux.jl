using Mux
using Test
using HTTP
import HTTP.ExceptionRequest: StatusError

@test Mux.notfound()(Dict())[:status] == 404
d1 = Dict("one"=> "1", "two"=> "2")
d2 = Dict("one"=> "1", "two"=> "")
# Test basic server
@app test = (
  Mux.defaults,
  page("/",respond("<h1>Hello World!</h1>")),
  page("/about", respond("<h1>Boo!</h1>")),
  page("/user/:user", req -> "<h1>Hello, $(req[:params][:user])!</h1>"),
  query(d1, respond("<h1>query1</h1>")),
  query(d2, respond("<h1>query2</h1>")),
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

# Query based routing
@test String(HTTP.get("http://localhost:8000/dum?one=1&two=2").body) ==
            "<h1>query1</h1>"
@test_throws StatusError String(HTTP.get("http://localhost:8000/dum?one=1").body)
@test_throws StatusError String(HTTP.get("http://localhost:8000/dum?one=1&two=2&sarv=boo").body)
@test_throws StatusError String(HTTP.get("http://localhost:8000/dum?one=1").body)
@test String(HTTP.get("http://localhost:8000/dum?one=1&two=56").body) ==
            "<h1>query2</h1>"
@test String(HTTP.get("http://localhost:8000/dum?one=1&two=hfjd").body) ==
            "<h1>query2</h1>"
@test_throws StatusError String(HTTP.get("http://localhost:8000/dum?one=1&two=2&sarv=boo").body)

throwapp() = (_...) -> error("An error!")
# Used for wrapping stderrcatch so we can check its output and stop it spewing
# all over the test results.
path, mock_stderr = mktemp()

# Test production server
@app test = (
  Mux.prod_defaults,
  (app, req) -> redirect_stderr(() -> Mux.stderrcatch(app, req), mock_stderr),
  page("/",respond("<h1>Hello World!</h1>")),
  page("/about", respond("<h1>Boo!</h1>")),
  page("/user/:user", req -> "<h1>Hello, $(req[:params][:user])!</h1>"),
  throwapp(),
  Mux.notfound())
serve(test, 8001)
@test String(HTTP.get("http://localhost:8001").body) ==
            "<h1>Hello World!</h1>"
@test String(HTTP.get("http://localhost:8001/about").body) ==
            "<h1>Boo!</h1>"
@test String(HTTP.get("http://localhost:8001/user/julia").body) ==
            "<h1>Hello, julia!</h1>"
@test String(HTTP.get("http://localhost:8001/badurl";
                      status_exception=false).body) ==
             "Internal server error"
seekstart(mock_stderr)
@test occursin("An error!", read(mock_stderr, String))
close(mock_stderr)
rm(path)

# Test page and route are callable without a string argument
# (previously the first two raised StackOverflowError)
@test page(identity, identity) isa Function
@test route(identity, identity) isa Function
@test page(identity) isa Function
@test route(identity) isa Function

# Test you can pass the string last if you really want.
@test page(identity, "") isa Function
@test route(identity, "") isa Function

@testset "WebSockets" begin
  import Mux.WebSockets

  @app h = (
      Mux.defaults,
      page("/", respond("<h1>Hello World!</h1>")),
      Mux.notfound());
    
  @app w = (
      Mux.wdefaults,
      route("/ws_io", Mux.echo),
      Mux.wclose,
      Mux.notfound());

  serve(h, w, 2333)

  WebSockets.open("ws://localhost:2333/ws_io") do ws_client
    message = "Hello WebSocket!"
    WebSockets.writeguarded(ws_client, message)
    data, success = WebSockets.readguarded(ws_client)
    @test success
    @test String(data) == message
  end
end
