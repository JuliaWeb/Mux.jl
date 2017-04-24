export wrap_cookies

function wrap_cookies(app, req)
  response    = app(req)
  cookies     = get(response, "cookies", Dict{String, Cookie}())

  cookies_dic = Dict{String, Cookie}()
  for (name, dic) in cookies
    cookies_dic[name] = Cookie(name, dic["value"])
  end

  response["cookies"] = cookies_dic

  response
end

