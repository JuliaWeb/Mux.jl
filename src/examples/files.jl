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
        Pkg.dir(pkg, ASSETS_DIR)
    end

    branch(req -> validpath(absdir(req), joinpath(req[:path]...), dirs=dirs),
           req -> (Base.warn_once("""
                        Relying on /pkg/ is now deprecated. Please use the package
                        `AssetRegistry.jl` instead to register assets directory
                        """);
                   fresp(joinpath(absdir(req), req[:path]...))))
end

const pkgfiles = route("pkg/:pkg", packagefiles(), Mux.notfound())


using AssetRegistry

function assetserve(dirs=true)
    absdir(req) = AssetRegistry.registry["/assetserver/" * req[:params][:key]]
    branch(req -> (isfile(absdir(req)) && isempty(req[:path])) ||
           validpath(absdir(req), joinpath(req[:path]...), dirs=dirs),
           req -> fresp(joinpath(absdir(req), req[:path]...)))
end

const assetserver = route("assetserver/:key", assetserve(), Mux.notfound())
