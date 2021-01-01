module Difmap

using IterTools: groupby, partition
using Parameters: @with_kw
using difmap_jll


@with_kw struct ExecutionResult
    exitcode::Int
    success::Bool = exitcode == 0
    stdout::String
    stderr::String
    log::String
    outfiles::Vector
end

execute(script::Vector{String}; kwargs...) = execute(join(script, "\n"); kwargs...)

function execute(script::String; in_files=[], out_files=[], out_files_overwrite=false)
    original_dir = pwd()
    mktempdir() do tmp_dir
        @debug "Running difmap in $tmp_dir"
        cd(tmp_dir) do
            if !isempty(in_files)
                @debug "Copying files $in_files from $original_dir to $tmp_dir"
                for (from, to) in in_files
                    @assert !occursin("/", to) to
                    cp(joinpath(original_dir, from), to)
                end
            end
            @assert !isfile("difmap.log")
            @assert !isfile("commands")
            open("commands", "w") do f
                write(f, script)
            end
            difmap() do exe
                out = Pipe()
                err = Pipe()
                process = run(pipeline(`$exe` |> ignorestatus, stdin="commands", stdout=out, stderr=err), wait=true)
                close(out.in)
                close(err.in)
              
                files = map(filter(f -> f ∉ ["commands", "difmap.log"] && f ∉ last.(in_files), readdir())) do f
                    (name=f, size=stat(f).size)
                end
                @assert setdiff(sort([f.name for f in files]), sort(first.(out_files))) |> isempty   files
                if !isempty(out_files)
                    @debug "Copying files $out_files from $tmp_dir to $original_dir"
                    for (from, to) in out_files
                        @assert isfile(from)
                        if to != nothing
                            cp(from, joinpath(original_dir, to), force=out_files_overwrite)
                        end
                    end
                end
                return ExecutionResult(
                    exitcode=process.exitcode,
                    stdout=read(out, String),
                    stderr=read(err, String),
                    log=read("difmap.log", String),
                    outfiles=files,
                )
            end
        end
    end
end

inputlines(res::ExecutionResult) = filter(s -> !isempty(s) && !startswith(s, "! "), split(res.log, "\n"))
outputlines(res::ExecutionResult) = map(s -> strip(s[2:end]), filter(s -> startswith(s, "! "), split(res.log, "\n")))

function inout_pairs(res::ExecutionResult)
    lines = map(s -> (line=s, kind=startswith(s, "! ") ? :out : :in), split(res.log, "\n"))
    result = ["" => String[]]
    for s in lines
        if s.kind == :in && !isempty(s.line)
            push!(result, s.line => [])
        elseif s.kind == :out
            push!(result[end].second, strip(s.line[2:end]))
        end
    end
    return result
end

end
