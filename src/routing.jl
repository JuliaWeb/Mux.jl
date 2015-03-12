using HttpCommon

export method, GET, websocket, route, page, probabilty

# Request type

method(m::String, app) = branch(req -> req[:method] == m, app)
method(ms, app) = branch(req -> req[:method] in ms, app)
method(m, app...) = method(m, mux(app...))

GET(app...) = method("GET", app...)

# Path routing

splitpath(p::String) = split(p, "/", false)
splitpath(p) = p

function matchpath(target, path)
  length(target) > length(path) && return
  params = @d()
  for i = 1:length(target)
    if beginswith(target[i], ":")
      params[symbol(target[i][2:end])] = path[i]
    else
      target[i] == path[i] || return
    end
  end
  return params
end

function matchpath!(target, req)
  ps = matchpath(target, req[:path])
  ps == nothing && return false
  merge!(params!(req), ps)
  splice!(req[:path], 1:length(target))
  return true
end

websocket(app) = branch(req->haskey(req, :websocket), app)

route(p, app) = branch(req -> matchpath!(p, req), app)
route(p::String, app) = route(splitpath(p), app)
route(p, app...) = route(p, mux(app...))

page(p::Vector, app) = branch(req -> length(p) == length(req[:path]) && matchpath!(p, req), app)
page(p::String, app) = page(splitpath(p), app)
page(p, app...) = page(p, mux(app...))
page(app) = page([], app)

# Misc

probabilty(x, app) = branch(_->rand()<x, app)
