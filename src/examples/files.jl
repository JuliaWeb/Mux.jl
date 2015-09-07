using Hiccup
import Hiccup.div
import HttpServer.mimetypes

export files

Base.joinpath() = ""

function validpath(root, path; dirs = true)
  full = normpath(root, path)
  @compat startswith(full, root) &&
    (isfile(full) || (dirs && isdir(full)))
end

ormatch(r::RegexMatch, x) = r.match
ormatch(r::Nothing, x) = x

extension(f) = ormatch(match(r"(?<=\.)[^\.\\/]*$", f), "")

fileheaders(f) = @d("Content-Type" => get(mimetypes, extension(f), "application/octet-stream"))

fileresponse(f) = @d(:file => f,
                     :body => open(readbytes, f),
                     :headers => fileheaders(f))

fresp(f) =
  isfile(f) ? fileresponse(f) :
  isdir(f) ?  dirresponse(f) :
  error("$f doesn't exist")

files(root, dirs = true) =
  branch(req -> validpath(root, joinpath(req[:path]...), dirs=dirs),
         req -> fresp(joinpath(root, req[:path]...)))

# Directories

files_css = """
  table { width:100%; border-radius:5px; }
  td { padding: 5px; }
  tr:nth-child(odd) { background: #f4f4ff; }
  .size { text-align: right; }
  """

function filelink(root, f)
  isdir(joinpath(root, f)) && (f = "$f/")
  a(@d(:href=>f), f)
end

dirresponse(f) =
  html(head(style([mux_css, files_css])),
       body(h1("Files"),
            div(".box", table([tr(td(".file", filelink(f, x)),
                                  td(".size", string(filesize(joinpath(f, x)))))
                               for x in ["..", readdir(f)...]]))))
