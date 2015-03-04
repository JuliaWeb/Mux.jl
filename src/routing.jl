splitpath(p::String) = split(p, "/", false)
splitpath(p) = p

mif(p, app) = (app′, req) -> go(p(req) ? app : app′, req)

# Request type

# Path routing

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

route(p, app) = mif(req -> matchpath!(p, req), app)
route(p::String, app) = route(splitpath(p), app)
route(p, app...) = route(p, stack(app...))

page(p::Vector, app) = mif(req -> length(p) == length(req[:path]) && matchpath!(p, req), app)
page(p::String, app) = page(splitpath(p), app)
page(p, app...) = page(p, stack(app...))

probabilty(x, app) = mif(_->rand()<x, app)
