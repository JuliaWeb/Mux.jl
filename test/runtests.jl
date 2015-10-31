using Mux
using Base.Test
using Lazy

# write your own tests here
@test 1 == 1

@test Mux.notfound()(d())[:status] == 404