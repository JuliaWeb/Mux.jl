module Mux

export go, stack

# This might be the smallest core ever.

null(app, req) = Dict()
go(app, req) = app(null, req)
stack(a, b) = (app, req) -> a((_, req) -> b(app, req), req)
stack(ms...) = reduce(stack, ms)
branch(p, app) = (app′, req) -> go(p(req) ? app : app′, req)

# May as well provide a few conveniences, though.

include("server.jl")
include("basics.jl")
include("routing.jl")
include("implementations.jl")

defaults = stack(todict, splitquery, toresponse)

end
