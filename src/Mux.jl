module Mux

export mux, stack, branch

using Base64: stringmime

# This might be the smallest core ever.

mux(f) = f
mux(m, f) = x -> m(f, x)
mux(ms...) = foldr(mux, ms)

stack(m) = m
stack(m, n) = (f, x) -> m(mux(n, f), x)
stack(ms...) = foldl(stack, ms)

branch(p, t) = (f, x) -> (p(x) ? t : f)(x)
branch(p, t...) = branch(p, mux(t...))

# May as well provide a few conveniences, though.

using Hiccup

include("lazy.jl")
include("server.jl")
include("basics.jl")
include("routing.jl")

include("websockets_integration.jl")

include("examples/mimetypes.jl")
include("examples/basic.jl")
include("examples/files.jl")

defaults = stack(todict, basiccatch, splitquery, toresponse, assetserver, pkgfiles)
wdefaults = stack(todict, wcatch, splitquery)
prod_defaults = stack(todict, stderrcatch, splitquery, toresponse, assetserver, pkgfiles)

end
