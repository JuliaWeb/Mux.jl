using HttpCommon

export method, GET, route, page, probabilty

# Request type

method(m::String, app...) = branch(req -> req[:method] == m, app...)
method(ms, app...) = branch(req -> req[:method] in ms, app...)

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

route(p, app...) = branch(req -> matchpath!(p, req), app...)
route(p::String, app...) = route(splitpath(p), app...)
route(app::Function, p) = route(p, app)

page(p::Vector, app...) = branch(req -> length(p) == length(req[:path]) && matchpath!(p, req), app...)
page(p::String, app...) = page(splitpath(p), app...)
page(app...) = page([], app...)
page(app::Function, p) = page(p, app)

# Misc

probabilty(x, app...) = branch(_->rand()<x, app...)
