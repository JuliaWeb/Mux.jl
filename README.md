# Mux.jl

Mux.jl is a middleware library for Julia, which allows web services to
be easily composed from modular, independent components.

In Mux, everything is middleware. *Everything*. This means it's
ridiculously composable – you can build up a portion of your app, then
either just run it or carry on composing pieces together.

Middleware is simply a function (see below)

    app, request -> response

Apps are run with

    go(app, req)

Middleware/apps are composed with:

    stack(a, b)

Defining middleware is easy:

    function mymiddle(app, req)
      # (optionally) do something with `req`
      res = go(app, req)
      # (optionally) do something with `res`
    end

Once you've defined middleware, you can use it however you want. `stack`
is self-flattening, so you can easily build larger apps out of smaller
pieces.

    stack(a, b, c, d) == stack(a, stack(b, c), d) == stack(stack(a, b, c), d) etc.
