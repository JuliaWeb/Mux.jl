"""
    mux_showerror(io, exc, bt)

`showerror(io, exc, bt)`, but simplify the printing of all those Mux closures.
"""
function mux_showerror(io, e, bt)
  buf = IOBuffer()
  showerror(buf, e, bt)
  str = String(take!(buf))
  write(io, rename_mux_closures(str))
end

"""
    find_matching_index(str, idx, closing_char)

Find the index in `str` of the matching `closing_char` for the opening character at `idx`, or `nothing` if there is no matching character.

If there is a matching character, `str[idx:find_matching_index(str, idx, closing_char)]` will contain:

- n opening characters, where 1 ≤ n
- m closing characters, where 1 ≤ m ≤ n

The interior opening and closing characters need not be balanced.

# Examples

```
julia> find_closing_char("((()))", 1, ')')
6

julia> find_closing_char("Vector{Union{Int64, Float64}}()", 7, '}')
29
```
"""
function find_closing_char(str, idx, closing_char)
  opening_char = str[idx]
  open = 1
  while open != 0 && idx < lastindex(str)
    idx = nextind(str, idx)
    char = str[idx]
    if char == opening_char
      open += 1
    elseif char == closing_char
      open -= 1
    end
  end
  return open == 0 ? idx : nothing
end

"""
    rename_mux_closures(str)

Replace all anonymous "Mux.var" closures in `str` with "Mux.Closure" to make backtraces easier to read.
"""
function rename_mux_closures(str)
  maybe_idx = findfirst(r"Mux\.var\"#\w+#\w+\"{", str)
  if isnothing(maybe_idx)
    return str
  else
    start_idx, brace_idx = extrema(maybe_idx)
  end
  maybe_idx = find_closing_char(str, brace_idx, '}')
  if !isnothing(maybe_idx)
    suffix = maybe_idx == lastindex(str) ? "" : str[nextind(str, maybe_idx):end]
    str = str[1:prevind(str, start_idx)] * "Mux.Closure" * suffix
    rename_mux_closures(str)
  else
    str
  end
end

"""
    Closure

Mux doesn't really use this type, we just print `Mux.Closure` instead of `Mux.var"#1#2{Mux.var"#3#4"{...}}` in stacktraces to make them easier to read.
"""
struct Closure
  Closure() = error("""Mux doesn't really use this type, we just print `Mux.Closure` instead of `Mux.var"#1#2{Mux.var"#3#4"{...}}` in stacktraces to make them easier to read.""")
end
