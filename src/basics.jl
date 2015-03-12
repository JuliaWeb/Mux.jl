using Lazy, HttpServer, HttpCommon, URIParser

export respond, mux

# Utils

pre(f) = (app, req) -> app(f(req))
post(f) = (app, req) -> f(app(req))

# Request

function todict(app, req)
  req′ = Dict()
  req′[:method]   = req.method
  req′[:headers]  = req.headers
  req′[:resource] = req.resource
  req.data != "" && (req′[:data] = req.data)
  app(req′)
end

function splitquery(app, req)
  uri = URI(req[:resource])
  delete!(req, :resource)
  req[:path]  = splitpath(uri.path)
  req[:query] = uri.query
  app(req)
end


function withwebsocket(sock)
  # giving this function a name because the error
  # messages get better.
  function websocket_middleware(app, req)
    req[:websock] = sock
    app(req)
  end
end

params!(req) = get!(req, :params, @d())

# Response

import HttpCommon: Response

Response(d::Associative) =
  Response(get(d, :status, 200),
           get(d, :headers, HttpCommon.headers()),
           get(d, :body, ""))

response(d) = d
response(s::String) = @d(:body=>s)

toresponse(app, req) = Response(response(app(req)))

respond(res) = req -> response(res)

reskey(k, v) = post(res -> merge!(res, @d(k=>v)))

status(s) = reskey(:status, s)

# Error handling

mux_css = """
  <style>
  body { font-family: sans-serif; padding:50px; }
  .box { background: #fcfcff; padding:20px; border: 1px solid #ddd; border-radius:5px; }
  pre { line-height:1.5 }
  u { cursor: pointer }
  </style>
  """

error_phrases = ["Looks like someone needs to pay their developers more."
                 "Someone order a thousand more monkeys! And a million more typewriters!"
                 "Maybe it's time for some sleep?"
                 "Don't bother debugging this one – it's almost definitely a quantum thingy."
                 "It probably won't happen again though, right?"
                 "F5! F5! F5!"
                 "F5! F5! FFS!"
                 "On the bright side, nothing has exploded. Yet."
                 "If this error has frustrated you, try clicking <u>here</u>."]

function basiccatch(app, req)
  try
    app(req)
  catch e
    io = IOBuffer()
    println(io, mux_css)
    println(io, "<h1>Internal Error</h1>")
    println(io, "<p>$(error_phrases[rand(1:length(error_phrases))])</p>")
    println(io, "<pre class=\"box\">")
    showerror(io, e, catch_backtrace())
    println(io, "</pre>")
    return @d(:status => 500, :body => takebuf_string(io))
  end
end
