# Mux.jl

[![Build Status](https://travis-ci.org/JuliaWeb/Mux.jl.svg?branch=master)](https://travis-ci.org/JuliaWeb/Mux.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/iuyp5jrre7s905ay/branch/master?svg=true)](https://ci.appveyor.com/project/shashi/mux-jl/branch/master)
[![codecov.io](https://codecov.io/github/JuliaWeb/Mux.jl/coverage.svg?branch=master)](https://codecov.io/github/JuliaWeb/Mux.jl?branch=master)

[![Mux](http://pkg.julialang.org/badges/Mux_0.3.svg)](http://pkg.julialang.org/?pkg=Mux)
[![Mux](http://pkg.julialang.org/badges/Mux_0.4.svg)](http://pkg.julialang.org/?pkg=Mux)

```jl
Pkg.add("Mux")
```

Mux.jl gives your Julia web services some closure. Mux allows you to
define servers in terms of highly modular and composable components
called middleware, with the aim of making both simple and complex
servers as simple as possible to throw together.

For example:

```jl
using Mux

@app test = (
  Mux.defaults,
  page(respond("<h1>Hello World!</h1>")),
  page("/about",
       probability(0.1, respond("<h1>Boo!</h1>")),
       respond("<h1>About Me</h1>")),
  page("/user/:user", req -> "<h1>Hello, $(req[:params][:user])!</h1>"),
  Mux.notfound())

serve(test)
```

You can run this demo by entering the successive forms into the Julia
REPL. The code displays a "hello, world" at `localhost:8000`, with an
about page at `/about` and another hello at `/user/[your name]`.

The `@app` macro allows the server to be redefined on the fly, and you
can test this by editing the `hello` text and re-evaluating. (don't
re-evalute `serve(test)`)

## Technical Overview

Mux.jl is at heart a control flow library, with a [very small core](https://github.com/one-more-minute/Mux.jl/blob/master/src/Mux.jl#L7-L16). It's not important to understand that code exactly as long as you understand what it achieves.

There are three concepts core to Mux.jl: Middleware (which should be familiar
from the web libraries of other languages), stacking, and branching.

### Apps and Middleware

An *app* or *endpoint* is simply a function of a request which produces
a response:

```jl
function myapp(req)
  return "<h1>Hello, $(req[:params][:user])!</h1>"
end
```

In principle this should say "hi" to our lovely user. But we have a
problem – where does the user's name come from? Ideally, our app
function doesn't need to know – it's simply handled at some point up the
chain (just the same as we don't parse the raw HTTP data, for example).

One way to solve this is via *middleware*. Say we get `:user` from a cookie:

```jl
function username(app, req)
  req[:params][:user] = req[:cookies][:user]
  return app(req) # We could also alter the response, but don't want to here
end
```

Middleware simply takes our request and modifies it appropriately, so
that data needed later on is available. This example is pretty trivial,
but we could equally have middleware which handles authentication and
encryption, processes cookies or file uploads, provides default headers,
and more.

We can then call our new version of the app like this:

```jl
username(myapp, req)
```

In fact, we can generate a whole new version of the app which has username
support built in:

```jl
function app2(req)
  return username(myapp, req)
end
```

But if we have a lot of middleware, we're going to end up with a lot of `appX` functions.
For that reason we can use the `mux` function instead, which creates the new app for us:

```jl
mux(username, myapp)
```

This returns a *new* function which is equivalent to `app2` above. We
just didn't have to write it by hand.

### Stacking

Now suppose you have lots of middleware – one to parse the HTTP request into
a dict of properties, one to check user authentication, one to catches errors,
etc. `mux` handles this too – just pass it multiple arguments:

```jl
mux(todict, auth, catch_errors, app)
```

Again, `mux` returns a whole new app (a `request -> response` function)
for us, this time wrapped with the three middlewares we provided.
`todict` will be the first to make changes to the incoming request, and
the last to alter the outgoing response.

Another neat thing we can do is to compose middleware into more middleware:

```jl
mymidware = stack(todict, auth, catch_errors)
mux(mymidware, app)
```

This is effectively equivalent to the `mux` call above, but creating a
new middleware function from independent parts means we're able to
factor out our service to make things more readable. For example, Mux
provides the `Mux.default` middleware which is actually just a stack of
useful tools.

`stack` is self-flattening, i.e.

```jl
stack(a, b, c, d) == stack(a, stack(b, c), d) == stack(stack(a, b, c), d)
```

etc.

### Branching

Mux.jl goes further with middleware, and expresses routing and decisions
as middleware themselves. The key to this is the `branch` function,
which takes

1. a predicate to apply to the incoming request, and
2. an endpoint to run on the request if the predicate returns true.

For example:

```jl
mux(branch(_ -> rand() < 0.1, respond("Hello")),
    respond("Hi"))
```

In this example, we ignore the request and simply return true 10% of the time.
You can test this in the repl by calling

```jl
mux(branch(_ -> rand() < 0.1, respond("Hello")),
    respond("Hi"))(nothing)
```

(since the request is ignored anyway, it doesn't matter if we set it to `nothing`).

We can also define a function to wrap the branch

```jl
probability(x, app) = branch(_ -> rand() < x, app)
```

### Utilities

Despite the fact that endpoints and middleware are so important in Mux,
it's common to not write them by hand. For example, `respond("hi")`
creates a function `_ -> "hi"` which can be used as an endpoint.
Equally, functions like `status(404)` will create middleware which
applies the given status to the response. Mux.jl's "not found" endpoint
is therefore defined as

```jl
notfound(s = "Not found") = mux(status(404), respond(s))
```

which is a much more declarative approach.

For example:

* `respond(x)` – creates an endpoint that responds with `x`, regardless of the request.
* `route("/path/here", app)` – branches to `app` if the request location matches `"/path/here"`.
* `page("/path/here", app)` – branches to `app` if the request location *exactly* matches `"/path/here"`

## Serving static files from a package

Please use [AssetRegistry.jl](https://github.com/JuliaGizmos/AssetRegistry.jl) to
register an assets directory.

**DEPRECATED**: The `Mux.pkgfiles` middleware (included in `Mux.defaults`) serves static
files under the `assets` directory in any Julia package at `/pkg/<PACKAGE>/`.

## Integrate with WebSocket

You can easily integrate a general HTTP server and a WebSocket server with Mux, here is an example:

Firstly, let's import some modules:

```
using Mux
import Mux.WebSockets
```

Next, let's define the behavior of HTTP server and WebSocket server:

```
@app h = (
    Mux.defaults,
    page("/", respond("<h1>Hello World!</h1>")),
    Mux.notfound());
    
function ws_io(x)
    conn = x[:socket]

    while !eof(conn)
        data = WebSockets.readguarded(conn)
        data_str = String(data[1])
        println("Received data: " * data_str)

        WebSockets.writeguarded(conn, "Hey, I've received " * data_str)
    end
end

@app w = (
    Mux.wdefaults,
    route("/ws_io", ws_io),
    Mux.wclose,
    Mux.notfound());
 ```
 
Run the server:
 
```
WebSockets.serve(
    WebSockets.ServerWS(
        Mux.http_handler(h),
        Mux.ws_handler(w),
    ), 2333);
```

And finally, in a separate Julia process, run a client:

```
using Mux
import Mux.WebSockets

WebSockets.open("ws://localhost:2333/ws_io") do ws_client
    WebSockets.writeguarded(ws_client, "Hello World")
    data, success = WebSockets.readguarded(ws_client)
    if success
        println(stderr, ws_client, " received:", String(data))
    end
end
```

Now, if you run both programs, you'll see a `Hello World` message, as the
server is replying the same message back to the client.

## Using Mux in Production

While Mux should be perfectly useable in a Production environment, it is not
recommended to use the `Mux.defaults` stack for a Production application. The
`basiccatch` middleware it includes will dump potentially sensitive stacktraces
to the client on error, which is probably not what you want to be serving to
your clients! An alternative `Mux.prod_defaults` stack is available for
Production applications, which is just `Mux.defaults` with a `stderrcatch`
middleware instead (which dumps errors to stderr).
