export wrap_cookies

import Base.==
==(a::Cookie, b::Cookie) = a.name == b.name && a.value == b.value && a.attrs == b.attrs

function same_site_value(value)
  Dict("strict" => "Strict", "lax" => "Lax")[value]
end

function set_cookie_attrs(attrs::Dict)
  attrs_name_map = Dict("domain" => "Domain", "max-age" => "Max-Age", "path" => "Path",
                        "secure" => "Secure", "expires" => "Expires", "http-only" => "HttpOnly",
                        "same-site" => "SameSite")

  cookie_attrs = Dict{String, String}()
  for (name, value) in attrs
    if name != "value"
      attr_name = attrs_name_map[name]
      if value == true
        cookie_attrs[attr_name] = ""
      elseif value != false
        if name == "same-site"
          value = same_site_value(value)
        elseif name == "expires"
          if typeof(value) == Date
            value = Dates.format(value, Dates.RFC1123Format)
          else
            value = Dates.format(DateTime(value), Dates.RFC1123Format)
          end
        elseif name == "max-age"
          if typeof(value) != String && typeof(value) != Int
            value = convert(Dates.Second, value).value
          end
        end

        cookie_attrs[attr_name] = string(value)
      end
    end
  end

  cookie_attrs
end

function wrap_cookies(app, req)
  response    = app(req)
  cookies     = get(response, :cookies, Dict{String, Cookie}())

  cookies_dic = Dict{String, Cookie}()
  for (name, dic) in cookies
    cookies_dic[name] = Cookie(name, dic["value"], set_cookie_attrs(dic))
  end

  response[:cookies] = cookies_dic

  response
end
