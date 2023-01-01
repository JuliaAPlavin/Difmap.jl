@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    replace(read(path, String), "```julia" => "```jldoctest mylabel")
end module Difmap

using DataPipes
using difmap_jll
using ImageMagick_jll: imagemagick_convert, identify


Base.@kwdef struct ExecutionResult
    exitcode::Int
    success::Bool
    stdout::String
    stderr::String
    log::Union{String, Nothing}
    outfiles::Vector
end

Base.success(r::ExecutionResult) = r.success

execute(script::Vector{String}; kwargs...) = execute(join(script, "\n"); kwargs...)

function execute(script::String; in_files=[], out_files=[], out_files_overwrite=false)
    original_dir = pwd()
    mktempdir() do tmp_dir
        @debug "Running difmap in $tmp_dir"
        if !isempty(in_files)
            @debug "Copying files $in_files from $original_dir to $tmp_dir"
            for (from, to) in in_files
                @assert !occursin("/", to) to
                cp(joinpath(original_dir, from), joinpath(tmp_dir, to))
            end
        end
        @assert !isfile(joinpath(tmp_dir, "difmap.log"))
        @assert !isfile(joinpath(tmp_dir, "commands"))
        open(joinpath(tmp_dir, "commands"), "w") do f
            write(f, script)
        end
        
        out = joinpath(tmp_dir, "__stdout")
        err = joinpath(tmp_dir, "__stderr")
        cmd = Cmd(`$(difmap())`, ignorestatus=true, dir=tmp_dir)
        process = run(pipeline(cmd, stdin=joinpath(tmp_dir, "commands"), stdout=out, stderr=err), wait=true)
        success = process.exitcode == 0

        files = @p begin
            readdir(tmp_dir)
            filter(_ ∉ ["commands", "difmap.log"] && _ ∉ last.(in_files) && !startswith(_, "__"))
            map() do f
                if f ∈ first.(out_files)
                    tgt = @p out_files |> filter(_[1] == f) |> only() |> __[2]
                    isnothing(tgt) && return (name=f, path=nothing)
                    tgt = joinpath(original_dir, tgt)
                    cp(joinpath(tmp_dir, f), tgt, force=out_files_overwrite)
                    (name=f, path=tgt)
                else
                    (name=f, path=nothing)
                end
            end
        end
        return ExecutionResult(
            exitcode=process.exitcode,
            success=success,
            stdout=read(out, String),
            stderr=read(err, String),
            log=isfile(joinpath(tmp_dir, "difmap.log")) ? read(joinpath(tmp_dir, "difmap.log"), String) : nothing,
            outfiles=files,
        )
    end
end

inputlines(res::ExecutionResult) = inputlines(res.log)
inputlines(log::String) = @p split(log, "\n") |> filter(!isempty(_) && !startswith(_, "! "))
outputlines(res::ExecutionResult) = outputlines(res.log)
outputlines(log::String) = @p split(log, "\n") |> filter(startswith(_, "! ")) |> map(strip(_[2:end]))

inout_pairs(res::ExecutionResult) = inout_pairs(res.log)
function inout_pairs(log::String)
    lines = @p split(log, "\n") |> map((line=_, kind=startswith(_, "! ") ? :out : :in))
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

struct Plot
    file::String
end

function Base.show(io::IO, ::MIME"image/png", p::Plot)
    open(p.file) do f
        write(io, f)
    end
end

function plots(res::ExecutionResult, args=`-density 100`)
    @p res.outfiles |> filtermap(_.path) |> filtermap() do p
        outfile = tempname()
        identify() do exe
            r = run(`$exe $p`; wait=false)
            @show read(ignorestatus(`$exe $p`), String)
            success(r)
        end || return nothing
        imagemagick_convert() do exe
            run(`$exe $args $(p) PNG:$(outfile)`)
        end
        Plot(outfile)
    end
end

end
