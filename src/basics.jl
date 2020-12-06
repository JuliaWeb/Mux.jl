import HTTP
import HTTP.Request

export respond

# Utils

pre(f) = (app, req) -> app(f(req))
post(f) = (app, req) -> f(app(req))

# Request

using HTTP.URIs: URI

function todict(req::Request)
  req′ = Dict()
  req′[:method]   = req.method
  req′[:headers]  = req.headers
  req′[:resource] = req.target
  req′[:data] = req.body
  req′[:uri] = URI(req.target)
  req′[:cookies]  = HTTP.Cookies.cookies(req)
  return req′
end

todict(app, req) = app(todict(req))

function splitquery(app, req)
  uri = URI(req[:resource])
  delete!(req, :resource)
  req[:path] = splitpath(uri.path)
  req[:query] = uri.query
  app(req)
end

params!(req) = get!(req, :params, d())

# Response

Response(d::AbstractDict) =
    HTTP.Response(get(d, :status, 200),
            get(d, :headers, HTTP.Headers());
            body = get(d, :body, ""))


Response(o) = HTTP.Response(stringmime(MIME"text/html"(), o))

response(d) = d
response(s::AbstractString) = d(:body=>s)

toresponse(app, req) = Response(response(app(req)))

respond(res) = req -> response(res)

reskey(k, v) = post(res -> merge!(res, d(k=>v)))

status(s) = reskey(:status, s)

# Error handling

mux_css = """
  body { font-family: sans-serif; padding:50px; }
  .box { background: #fcfcff; padding:20px; border: 1px solid #ddd; border-radius:5px; white-space: pre-wrap; word-wrap: break-word; }
  pre { line-height:1.5 }
  a { text-decoration:none; color:#225; }
  a:hover { color:#336; }
  u { cursor: pointer }
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
    println(io, "<style>", mux_css, "</style>")
    println(io, "<h1>Internal Error</h1>")
    println(io, "<p>$(error_phrases[rand(1:length(error_phrases))])</p>")
    println(io, "<pre class=\"box\">")
    showerror(io, e, catch_backtrace())
    println(io, "</pre>")
    return d(:status => 500, :body => codeunits(String(take!(io))))
  end
end

function stderrcatch(app, req)
  try
    app(req)
  catch e
    showerror(stderr, e, catch_backtrace())
    return d(:status => 500, :body => codeunits("Internal server error"))
  end
end
