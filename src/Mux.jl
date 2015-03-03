module Mux

export go, stack

null(app, req) = Dict()
go(app, req) = app(null, req)
stack(a, b) = (app, req) -> a((_, req′) -> b(app, req′), req)
stack(ms...) = reduce(stack, ms)

include("basics.jl")

end
