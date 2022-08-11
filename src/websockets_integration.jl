using HTTP.WebSockets: WebSocket

function todict(sock::WebSocket)
 req′ = todict(sock.request)
 req′[:socket] = sock
 return req′
end

function wcatch(app, req)
  try
    app(req)
  catch e
    println(stderr, "Error handling websocket connection:")
    showerror(stderr, e, catch_backtrace())
  end
end

function wclose(_, req)
  close(req[:socket])
end

function echo(req)
  sock = req[:socket]
  for msg in sock
    send(sock, msg)
  end
end
