using WebSockets

function todict(rc::@compat Tuple{Request, WebSocket})
  req, client = rc
  req′ = todict(req)
  req′[:socket] = client
  return req′
end

function wcatch(app, req)
  try
    app(req)
  catch e
    println(STDERR, "Error handling websocket connection:")
    showerror(STDERR, e, catch_backtrace())
  end
end

function wclose(req)
  close(req[:socket])
end

function echo(req)
  sock = req[:socket]
  while isopen(sock)
    try
      write(sock, read(sock))
    end
  end
end
