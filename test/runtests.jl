using Mux
using Base.Test
using Lazy
import Requests

@test Mux.notfound()(d())[:status] == 404
d1 = Dict("one"=> "1", "two"=> "2")
d2 = Dict("one"=> "1", "two"=> "")
# Test basic server
@app test = (
  Mux.defaults,
  page(respond("<h1>Hello World!</h1>")),
  page("/about", respond("<h1>Boo!</h1>")),
  page("/user/:user", req -> "<h1>Hello, $(req[:params][:user])!</h1>"),
  query(d1, respond("<h1>query1</h1>")),
  query(d2, respond("<h1>query2</h1>")),
  Mux.notfound())
serve(test)
@test Requests.text(Requests.get("http://localhost:8000")) ==
            "<h1>Hello World!</h1>"
@test Requests.text(Requests.get("http://localhost:8000/about")) ==
            "<h1>Boo!</h1>"
@test Requests.text(Requests.get("http://localhost:8000/user/julia")) ==
            "<h1>Hello, julia!</h1>"
@test Requests.text(Requests.get("http://localhost:8000/dum?one=1&two=2")) == "<h1>query1</h1>"
@test Requests.text(Requests.get("http://localhost:8000/dum?one=1")) != "<h1>query1</h1>"
@test Requests.text(Requests.get("http://localhost:8000/dum?one=1&two=2&sarv=boo")) != "<h1>query1</h1>"
@test Requests.text(Requests.get("http://localhost:8000/dum?one=1")) != "<h1>query2</h1>"
@test Requests.text(Requests.get("http://localhost:8000/dum?one=1&two=56")) == "<h1>query2</h1>"
@test Requests.text(Requests.get("http://localhost:8000/dum?one=1&two=hfjd")) == "<h1>query2</h1>"
@test Requests.text(Requests.get("http://localhost:8000/dum?one=1&two=2&sarv=boo")) != "<h1>query2</h1>"
