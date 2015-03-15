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

files(root) =
  branch(req -> validpath(root, joinpath(req[:path]...), dirs=false),
         req -> fileresponse(joinpath(root, req[:path]...)))
