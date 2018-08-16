using WebSockets: WebSocket

function todict(rc::Tuple{Request, WebSocket})
 req, client = rc
 req′ = todict(req)
 req′[:socket] = client
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
  while isopen(sock)
    try
      write(sock, read(sock))
    catch
    end
  end
end
