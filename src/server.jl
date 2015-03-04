using HttpServer, Lazy

export @app, serve

type App
  warez
end

macro app (name, warez)
  quote
    if isdefined($(Expr(:quote, name)))
      $(esc(name)).warez = $(esc(warez))
    else
      const $(esc(name)) = App($(esc(warez)))
    end
    return $(esc(name))
  end
end

function serve(app::App, port = 8000)
  http = HttpHandler() do req, res
    return app.warez(req)
  end
  http.events["error"]  = (client, error) -> println(error)
  http.events["listen"] = (port)          -> println("Listening on $port...")
  @async @errs run(Server(http), port)
  return
end
