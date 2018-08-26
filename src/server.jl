using HTTP.Servers, Lazy, Sockets

import HTTP.HandlerFunction
import Base.Meta.isexpr
import WebSockets

export @app, serve

# `App` is just a box which allows the server to be
# redefined on the fly.
# In general these methods provide a simple way to
# get up and running, but aren't meant to be comprehensive.

mutable struct App
  warez
end

macro app(def)
  @assert isexpr(def, :(=))
  name, warez = def.args
  warez = isexpr(warez, :tuple) ? Expr(:call, :mux, map(esc, warez.args)...) : warez
  quote
    if @isdefined($name)
      $(esc(name)).warez = $warez
    else
      const $(esc(name)) = App($warez)
    end
    nothing
  end
end

# conversion functions for known http_handler return objects
mk_response(d) = d
function mk_response(d::Dict)
  r = HTTP.Response(get(d, :status, 200))
  haskey(d, :body) && (r.body = d[:body])
  haskey(d, :headers) && (r.headers = d[:headers])
  return r
end

function http_handler(app::App)
  handler = HandlerFunction((req) -> mk_response(app.warez(req)))
  # handler.events["error"]  = (client, error) -> println(error)
  # handler.events["listen"] = (port)          -> println("Listening on $port...")
  return handler
end

function ws_handler(app::App)
  handler = WebSockets.WebsocketHandler((req, client) -> mk_response(app.warez((req, client))))
  return handler
end

const default_port = 8000
const localhost = ip"127.0.0.1"

function serve(s::Server, host = localhost, port = default_port; kws...)
  @async @errs HTTP.serve(s, host, port; kws...)
  return
end

serve(s::Server, port::Integer) = serve(h, w, localhost, port)

serve(h::App, args...; kws...) =
    serve(Server(http_handler(h)), args...; kws...)

serve(h::App, w::App, host = localhost, port = default_port) =
    WebSockets.serve(WebSockets.ServerWS(http_handler(h), ws_handler(w)), host, port)

serve(h::App, w::App, port::Integer) = serve(h, w, localhost, port)
