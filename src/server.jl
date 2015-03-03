using HttpServer, Lazy

export @app, serve

type App
  warez
end

go(app::App, req) = go(app.warez, req)

macro app (name, warez)
  quote
    if isdefined($(Expr(:quote, name)))
      $name.warez = $warez
    else
      const $name = App($warez)
    end
    return $name
  end |> esc
end

function serve(app::App, port = 8000)
  http = HttpHandler() do req, res
    return go(app, req)
  end
  http.events["error"]  = (client, error) -> println(error)
  http.events["listen"] = (port)          -> println("Listening on $port...")
  @async @errs run(Server(http), port)
  return
end
