using Hiccup, Pkg
import Hiccup.div

export files

Base.joinpath() = ""

function validpath(root, path; dirs = true)
  full = normpath(root, path)
  startswith(full, root) &&
    (isfile(full) || (dirs && isdir(full)))
end

extension(f) = last(splitext(f))[2:end]

fileheaders(f) = d("Content-Type" => get(mimetypes, extension(f), "application/octet-stream"))

fileresponse(f) = d(:file => f,
                    :body => read(f),
                    :headers => fileheaders(f))

fresp(f) =
  isfile(f) ? fileresponse(f) :
  isdir(f) ?  dirresponse(f) :
  error("$f doesn't exist")

"""
    files(root, dirs=true)

Middleware to serve files in the directory specified by the absolute path `root`.

`req[:path]` will be combined with `root` to yield a filepath.
If the filepath is contained within `root` (after normalisation) and refers to an existing file (or directory if `dirs=true`), then respond with the file (or a directory listing), otherwise call the next middleware.

If you'd like to specify a `root` relative to your current working directory
or to the directory containing the file that your server is defined in, then
you can use `pwd()` or `@__DIR__`, and (if you need them) `joinpath` or `normpath`.

# Examples

```
files(pwd()) # serve files from the current working directory
files(@__DIR__) # serve files from the directory the script is in

# serve files from the assets directory in the same directory the script is in:
files(joinpath(@__DIR__, "assets"))

# serve files from the assets directory in the directory above the directory the script is in:
files(normpath(@__DIR__, "../assets))
```
"""
function files(root, dirs = true)
  branch(req -> validpath(root, joinpath(req[:path]...), dirs=dirs),
         req -> fresp(joinpath(root, req[:path]...)))
end

# Directories

files_css = """
  table { width:100%; border-radius:5px; }
  td { padding: 5px; }
  tr:nth-child(odd) { background: #f4f4ff; }
  .size { text-align: right; }
  """

function filelink(root, f)
  isdir(joinpath(root, f)) && (f = "$f/")
  a(d(:href=>f), f)
end

dirresponse(f) =
  html(head(style([mux_css, files_css])),
       body(h1("Files"),
            div(".box", table([tr(td(".file", filelink(f, x)),
                                  td(".size", string(filesize(joinpath(f, x)))))
                               for x in ["..", readdir(f)...]]))))

const ASSETS_DIR = "assets"
function packagefiles(dirs=true)
    loadpaths = LOAD_PATH
    function absdir(req)
        pkg = req[:params][:pkg]
        for p in loadpaths
            dir = joinpath(p, pkg, ASSETS_DIR)
            if isdir(dir)
                return dir
            end
        end
        Pkg.dir(String(pkg), ASSETS_DIR)  # Pkg.dir doesn't take SubString
    end

    branch(req -> validpath(absdir(req), joinpath(req[:path]...), dirs=dirs),
           req -> (Base.@warn("""
                        Relying on /pkg/ is now deprecated. Please use the package
                        `AssetRegistry.jl` instead to register assets directory
                        """, maxlog=1);
                   fresp(joinpath(absdir(req), req[:path]...))))
end

const pkgfiles = route("pkg/:pkg", packagefiles(), Mux.notfound())


using AssetRegistry

function assetserve(dirs=true)
    absdir(req) = AssetRegistry.registry["/assetserver/" * HTTP.unescapeuri(req[:params][:key])]
    path(req) = HTTP.unescapeuri.(req[:path])
    branch(req -> (isfile(absdir(req)) && isempty(req[:path])) ||
           validpath(absdir(req), joinpath(path(req)...), dirs=dirs),
           req -> fresp(joinpath(absdir(req), path(req)...)))
end

const assetserver = route("assetserver/:key", assetserve(), Mux.notfound())
