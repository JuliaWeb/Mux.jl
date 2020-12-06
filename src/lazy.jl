# Just the bits of Lazy.jl that we actually use.

macro errs(ex)
  :(try $(esc(ex))
    catch e
      showerror(stderr, e, catch_backtrace())
      println(stderr)
    end)
end

d(xs...) = Dict{Any, Any}(xs...)

