using Mux
using Base.Test
using Lazy
import Requests
import HttpCommon: Response, Cookie

@test Mux.notfound()(d())[:status] == 404

# Test basic server
@app test = (
  Mux.defaults,
  page(respond("<h1>Hello World!</h1>")),
  page("/about", respond("<h1>Boo!</h1>")),
  page("/user/:user", req -> "<h1>Hello, $(req[:params][:user])!</h1>"),
  Mux.notfound())
serve(test)
@test Requests.text(Requests.get("http://localhost:8000")) ==
            "<h1>Hello World!</h1>"
@test Requests.text(Requests.get("http://localhost:8000/about")) ==
            "<h1>Boo!</h1>"
@test Requests.text(Requests.get("http://localhost:8000/user/julia")) ==
            "<h1>Hello, julia!</h1>"

# Test Response d::Associative
import HttpCommon: Response, Cookie


response = Response(Dict(:status => 400, :cookies => Dict("cookies" => Cookie("cookie-name", "value"))))
@test response.cookies["cookies"].name == "cookie-name"

identity(arg) = arg
tests = [[Dict{Any,Any}(:cookies => Dict("a" => Dict("value" => "b"), "c" => Dict("value" => "d"))),
          Dict{Any,Any}("a" => Cookie("a", "b"), "c" => Cookie("c", "d")),
          "For mutiple cookies"],
         [Dict{Any,Any}(:cookies => Dict("a" => Dict("value" => "b", "path" => "/", "secure" => true, "http-only" => true))),
          Dict{Any,Any}("a" => Cookie("a", "b", Dict("Path" => "/", "Secure" => "", "HttpOnly" => ""))),
          "For path, secure and http-only"],
         [Dict{Any,Any}(:cookies => Dict("a" => Dict("value" => "b", "same-site" => "lax"))),
          Dict{Any,Any}("a" => Cookie("a", "b", Dict("SameSite" => "Lax" ))),
          "For same-site"],
         [Dict{Any,Any}(:cookies => Dict("a" => Dict("value" => "b", "expires" => DateTime(2015, 12, 31)))),
          Dict{Any,Any}("a" => Cookie("a", "b", Dict("Expires" => "Thu, 31 Dec 2015 00:00:00" ))),
          "For date time expires"],
         [Dict{Any,Any}(:cookies => Dict("a" => Dict("value" => "b", "expires" => "2015-12-31"))),
          Dict{Any,Any}("a" => Cookie("a", "b", Dict("Expires" => "Thu, 31 Dec 2015 00:00:00" ))),
          "For string expires"],
         [Dict{Any,Any}(:cookies => Dict("a" => Dict("value" => "b", "max-age" => 123))),
          Dict{Any,Any}("a" => Cookie("a", "b", Dict("Max-Age" => "123"))),
          "For max-age - integer"],
         [Dict{Any,Any}(:cookies => Dict("a" => Dict("value" => "b", "max-age" => Dates.Minute(1)))),
          Dict{Any,Any}("a" => Cookie("a", "b", Dict("Max-Age" => "60"))),
          "For max-age - type"]]

for (response, result, message) in tests
  println(message)
  cookies = Mux.wrap_cookies(identity, response)[:cookies]
  @test cookies == result
end
