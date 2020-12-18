using Sockets

import HTTP.RequestHandlerFunction
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
  warez = isexpr(warez, :tuple) ? Expr(:call, :mux, map(esc, warez.args)...) : esc(warez)
  quote
    if $(Expr(:isdefined, esc(name)))
      $(esc(name)).warez = $warez
    else
      $(esc(name)) = App($warez)
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
  handler = RequestHandlerFunction((req) -> mk_response(app.warez(req)))
  # handler.events["error"]  = (client, error) -> println(error)
  # handler.events["listen"] = (port)          -> println("Listening on $port...")
  return handler
end

function ws_handler(app::App)
  handler = WebSockets.WSHandlerFunction((req, client) -> mk_response(app.warez((req, client))))
  return handler
end

const default_port = 8000
const localhost = ip"0.0.0.0"

function serve(h::App, host = localhost, port = default_port; kws...)
  @async @errs HTTP.serve(http_handler(h), host, port; kws...)
end

serve(h::App, port::Integer) = serve(h, localhost, port)

serve(h::App, w::App, host = localhost, port = default_port) =
    @async @errs WebSockets.serve(WebSockets.ServerWS(http_handler(h), ws_handler(w)), host, port)

serve(h::App, w::App, port::Integer) = serve(h, w, localhost, port)
