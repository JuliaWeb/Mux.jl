using Lazy, HttpServer, URIParser

export showreq, showres

# Debugging

function showreq(app, req)
  @show req
  go(app, req)
end

function showres(app, req)
  res = go(app, req)
  @show res
  return res
end

# Extracting basic info

function todict(app, req)
  req′ = Dict()
  req′[:method]   = req.method
  req′[:headers]  = req.headers
  req′[:resource] = req.resource
  req.data != "" && (req′[:data] = req.data)
  go(app, req′)
end

function parsequery(app, req)
  uri = URI(req[:resource])
  delete!(req, :resource)
  req[:path]  = uri.path
  req[:query] = uri.query
  go(app, req)
end

defaults = stack(todict, parsequery)
