using HttpServer, Lazy, WebSockets

export @app, serve

type App
  warez
end

macro app (def)
  @assert isexpr(def, :(=))
  name, warez = def.args
  warez = isexpr(warez, :tuple) ? Expr(:call, :mux, map(esc, warez.args)...) : warez
  quote
    if isdefined($(Expr(:quote, name)))
      $(esc(name)).warez = $warez
    else
      const $(esc(name)) = App($warez)
    end
    nothing
  end
end


function serve(app::App, port = 8000)
  http = HttpHandler() do req, res
    return mux(todict, app.warez)(req)
  end
  http.events["error"]  = (client, error) -> println(error)
  http.events["listen"] = (port)          -> println("Listening on $port...")
  websock = WebSocketHandler() do req, sock
      mux(todict, withwebsocket(sock), app.warez)(req)
      if isopen(sock)
          close(sock)
      end
  end
  @async @errs run(Server(http, websock), port)
end
