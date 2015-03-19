using Hiccup

export files

Base.joinpath() = ""

function validpath(root, path; dirs = true)
  full = normpath(root, path)
  beginswith(full, root) &&
    (isfile(full) || (dirs && isdir(full)))
end

extension(f) = match(r"(?<=\.)[^\\/]*$|", f).match

fileheaders(f) = @d("Content-Type" => get(mimetypes, extension(f), "application/octet-stream"))

fileresponse(f) = @d(:file => f,
                     :body => open(readbytes, f),
                     :headers => fileheaders(f))

dirresponse(f) =
  html(head(),
       body(h2("Files"),
            div(table([tr(td(a(@d(:href=>"$x/"), x)),
                          td(string(filesize(joinpath(f, x)))))
                       for x in ["..", readdir(f)...]]))))

fresp(f) =
  isfile(f) ? fileresponse(f) :
  isdir(f) ?  dirresponse(f) :
  error("$f doesn't exist")

files(root, dirs = true) =
  branch(req -> validpath(root, joinpath(req[:path]...), dirs=dirs),
         req -> fresp(joinpath(root, req[:path]...)))
