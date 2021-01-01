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

function execute(script::String; move_files_to=nothing)
    mktempdir() do tmp_dir
        @info "Running difmap in $tmp_dir"
        cd(tmp_dir) do
            @assert !isfile("difmap.log")
            open("commands", "w") do f
                write(f, script)
            end
            difmap() do exe
                out = Pipe()
                err = Pipe()              
                process = run(pipeline(`$exe` |> ignorestatus, stdin="commands", stdout=out, stderr=err), wait=true)
                close(out.in)
                close(err.in)
              
                files = map(filter(f -> f ∉ ["commands", "difmap.log"], readdir())) do f
                    (name=f, size=stat(f).size)
                end
                if move_files_to !== nothing
                    @info "Moving files $files to $move_files_to"
                    for f in files
                        @assert isfile(f.name)
                        mv(f.name, joinpath(move_files_to, f.name))
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
