using Sockets

import Base.Meta.isexpr
import HTTP: WebSockets

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
  handler = (req) -> mk_response(app.warez(req))
  # handler.events["error"]  = (client, error) -> println(error)
  # handler.events["listen"] = (port)          -> println("Listening on $port...")
  return handler
end

function ws_handler(app::App)
  handler = (sock) -> mk_response(app.warez(sock))
  return handler
end

const default_port = 8000
const localhost = ip"0.0.0.0"

"""
    serve(h::App, host=$localhost, port=$default_port; kws...)
    serve(h::App, port::Int; kws...)

Serve the app `h` at the specified `host` and `port`. Keyword arguments are
passed to `HTTP.serve`.

Starts an async `Task`. Call `wait(serve(...))` in scripts where you want Julia
to wait until the server is terminated.
"""
function serve(h::App, host = localhost, port = default_port; kws...)
  @errs HTTP.serve!(http_handler(h), host, port; kws...)
end

serve(h::App, port::Integer; kws...) = serve(h, localhost, port; kws...)

"""
    serve(h::App, w::App, host=$localhost, port=$default_port, wsport=port+1; kwargs...)
    serve(h::App, w::App, port::Integer, wsport::Integer=port+1; kwargs...)

Start a server that uses `h` to serve regular HTTP requests and `w` to serve
WebSocket requests.
"""
function serve(h::App, w::App, host = localhost, port = default_port, wsport = port + 1; kws...)
    hsrvr = @errs HTTP.serve!(http_handler(h), host, port; kws...)
    wsrvr = @errs WebSockets.listen!(ws_handler(w), host, wsport; kws...)
    return (hsrvr, wsrvr)
end

serve(h::App, w::App, port::Integer, wsport::Integer=port+1; kwargs...) = serve(h, w, localhost, port, wsport; kwargs...)
