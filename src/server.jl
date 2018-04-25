using HTTP.Nitrogen, HTTP.HandlerFunction, Lazy

import Base.Meta.isexpr

export @app, serve

# `App` is just a box which allows the server to be
# redefined on the fly.
# In general these methods provide a simple way to
# get up and running, but aren't meant to be comprehensive.

type App
  warez
end

macro app(def)
  @assert isexpr(def, :(=))
  name, warez = def.args
  warez = isexpr(warez, :tuple) ? Expr(:call, :mux, map(esc, warez.args)...) : warez
  quote
    if isdefined($(Expr(:quote, name)))
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
  haskey(d, :body) && (r.body = HTTP.FIFOBuffer(d[:body]))
  haskey(d, :headers) && (r.headers = d[:headers])
  return r
end

function http_handler(app::App)
  handler = HandlerFunction((req, res) -> mk_response(app.warez(req)))
  # handler.events["error"]  = (client, error) -> println(error)
  # handler.events["listen"] = (port)          -> println("Listening on $port...")
  return handler
end

function ws_handler(app::App)
  handler = HandlerFunction((req, client) -> mk_response(app.warez((req, client))))
  return handler
end

const default_port = 8000
const localhost = ip"127.0.0.1"

function serve(s::Server, port = default_port; kws...)
  @async @errs HTTP.serve(s, localhost, port; kws...)
  return
end

serve(h::App, port = default_port; kws...) =
    serve(Server(http_handler(h)), port; kws...)

serve(h::App, w::App, port = default_port) =
    serve(Server(http_handler(h), ws_handler(w)), port)
