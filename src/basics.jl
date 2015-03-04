using Lazy, HttpServer, HttpCommon, URIParser

# Utils

pre(f) = (app, req) -> go(app, f(req))
post(f) = (app, req) -> f(go(app, req))

# Request

function todict(app, req)
  req′ = Dict()
  req′[:method]   = req.method
  req′[:headers]  = req.headers
  req′[:resource] = req.resource
  req.data != "" && (req′[:data] = req.data)
  go(app, req′)
end

function splitquery(app, req)
  uri = URI(req[:resource])
  delete!(req, :resource)
  req[:path]  = splitpath(uri.path)
  req[:query] = uri.query
  go(app, req)
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

toresponse(app, req) = Response(response(go(app, req)))

mux(app) = (_, req) -> response(app(req))
respond(res) = (_, req) -> response(res)

reskey(k, v) = post(res -> merge!(res, @d(k=>v)))

status(s) = reskey(:status, s)
