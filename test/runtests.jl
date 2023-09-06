using Mux
using Test
using HTTP, MbedTLS
import HTTP: StatusError, WebSockets

println("Mux")
@testset "Mux" begin

println("misc")
  @testset "misc" begin
  function f()
    @app foo = (Mux.defaults)
  end

  @test f() === nothing

  @test Mux.notfound()(Dict())[:status] == 404
end

println("basic server")
@testset "basic server" begin
  d1 = Dict("one"=> "1", "two"=> "2")
  d2 = Dict("one"=> "1", "two"=> "")
  @app test = (
    Mux.defaults,
    page("/",respond("<h1>Hello World!</h1>")),
    page("/about", respond("<h1>Boo!</h1>")),
    page("/user/:user", req -> "<h1>Hello, $(req[:params][:user])!</h1>"),
    query(d1, respond("<h1>query1</h1>")),
    query(d2, respond("<h1>query2</h1>")),
    Mux.notfound())
  serve(test)

  println("page")
  @testset "page" begin
    @test String(HTTP.get("http://localhost:8000").body) ==
                "<h1>Hello World!</h1>"
    @test String(HTTP.get("http://localhost:8000/about").body) ==
                "<h1>Boo!</h1>"
    @test String(HTTP.get("http://localhost:8000/user/julia").body) ==
                "<h1>Hello, julia!</h1>"
  end

  println("query")
  @testset "query" begin
    @test String(HTTP.get("http://localhost:8000/dum?one=1&two=2").body) ==
                "<h1>query1</h1>"
    @test_throws StatusError String(HTTP.get("http://localhost:8000/dum?one=1").body)
    @test_throws StatusError String(HTTP.get("http://localhost:8000/dum?one=1&two=2&sarv=boo").body)
    @test_throws StatusError String(HTTP.get("http://localhost:8000/dum?one=1").body)

    @test String(HTTP.get("http://localhost:8000/dum?one=1&two=56").body) ==
                "<h1>query2</h1>"
    @test String(HTTP.get("http://localhost:8000/dum?one=1&two=hfjd").body) ==
                "<h1>query2</h1>"
    @test_throws StatusError String(HTTP.get("http://localhost:8000/dum?one=1").body)
    @test_throws StatusError String(HTTP.get("http://localhost:8000/dum?one=1&two=2&sarv=boo").body)
  end
end

println("MIME types")
@testset "MIME types" begin
  # Issue #68
  @test Mux.fileheaders("foo.css")["Content-Type"] == "text/css"
  @test Mux.fileheaders("foo.html")["Content-Type"] == "text/html"
  @test Mux.fileheaders("foo.js")["Content-Type"] == "application/javascript"
end

# Check that prod_defaults don't completely break things
# And check prod_defaults error handler
println("prod defaults")
@testset "prod defaults" begin
  throwapp() = (_...) -> error("An error!")

  # Used for wrapping stderrcatch so we can check its output and stop it spewing
  # all over the test results.
  path, mock_stderr = mktemp()

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

  # Check our error was logged and close fake stderr
  seekstart(mock_stderr)
  @test occursin("An error!", read(mock_stderr, String))
  close(mock_stderr)
  rm(path)
end

# Test page and route are callable without a string argument
# (previously the first two raised StackOverflowError)
println("bare page()")
@testset "bare page()" begin
  @test page(identity, identity) isa Function
  @test route(identity, identity) isa Function
  @test page(identity) isa Function
  @test route(identity) isa Function

  # Test you can pass the string last if you really want.
  @test page(identity, "") isa Function
  @test route(identity, "") isa Function
end

println("WebSockets")
@testset "WebSockets" begin
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

  @test String(HTTP.get("http://localhost:2333/").body) ==
    "<h1>Hello World!</h1>"

  WebSockets.open("ws://localhost:2333/ws_io") do ws_client
    message = "Hello WebSocket!"
    WebSockets.send(ws_client, message)
    str = WebSockets.receive(ws_client)
    @test str == message
  end
end

println("SSL/TLS")
@testset "SSL/TLS" begin
  # Test that we can serve HTTP and websocket responses over TLS/SSL
  @app h = (
    Mux.defaults,
    page("/", respond("<h1>Hello World!</h1>")),
    Mux.notfound());

  @app w = (
    Mux.wdefaults,
    route("/ws_io", Mux.echo),
    Mux.wclose,
    Mux.notfound());

  cert = abspath(joinpath(dirname(pathof(Mux)), "../test", "test.cert"))
  key = abspath(joinpath(dirname(pathof(Mux)), "../test", "test.key"))
  serve(h, w, 2444; sslconfig=MbedTLS.SSLConfig(cert, key))

  # require_ssl_verification means that the certificates won't be validated
  # (checked against the certificate authority lists), but we will make proper
  # TLS/SSL connections, so the tests are still useful.

  http_response = HTTP.get("https://localhost:2444/"; require_ssl_verification=false)
  @test String(http_response.body) == "<h1>Hello World!</h1>"

  WebSockets.open("wss://localhost:2444/ws_io"; require_ssl_verification=false) do ws_client
    message = "Hello WebSocket!"
    WebSockets.send(ws_client, message)
    str = WebSockets.receive(ws_client)
    @test str == message
  end
end

@testset "rename_mux_closures" begin
  s1 = """
    [4] prettystderrcatch(app::Mux.var"#1#2"{typeof(test), Mux.var"#1#2"{Mux.var"#5#6"{Mux.var"#33#34"{Vector{Any}}, Mux.var"#23#24"{String}}, Mux.var"#1#2"{Mux.var"#5#6"{Mux.var"#33#34"{Vector{SubString{String}}}, Mux.var"#1#2"{Mux.var"#5#6"{Mux.var"#37#38"{Float64}, Mux.var"#23#24"{String}}, Mux.var"#23#24"{String}}}, Mux.var"#1#2"{Mux.var"#5#6"{Mux.var"#33#34"{Vector{SubString{String}}}, var"#5#7"}, Mux.var"#1#2"{Mux.var"#21#22"{Mux.var"#25#26"{Symbol, Int64}}, Mux.var"#23#24"{String}}}}}}, req::Dict{Any, Any})"""
  e1 = "[4] prettystderrcatch(app::Mux.Closure, req::Dict{Any, Any})"
  @test Mux.rename_mux_closures(s1) == e1

  s2 = """[21] (::Mux.var"#7#8"{Mux.App})(req::HTTP.Messages.Request)"""
  e2 = """[21] (::Mux.Closure)(req::HTTP.Messages.Request)"""
  @test Mux.rename_mux_closures(s2) == e2

  # Replace multiple closures at once
  @test Mux.rename_mux_closures(s1 * '\n' * s2) == e1 * '\n' * e2

  # Leave malformed input alone
  s3 = """gabble (::Mux.var"#7#8{ gabble"""
  @test Mux.rename_mux_closures(s3) == s3
end

end
