@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    replace(read(path, String), "```julia" => "```jldoctest mylabel")
end module Difmap

using difmap_jll


Base.@kwdef struct ExecutionResult
    exitcode::Int
    success::Bool
    stdout::String
    stderr::String
    log::Union{String, Nothing}
    outfiles::Vector
end

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

        files = map(filter(f -> f ∉ ["commands", "difmap.log"] && f ∉ last.(in_files) && !startswith(f, "__"), readdir(tmp_dir))) do f
            (name=f, size=stat(joinpath(tmp_dir, f)).size)
        end
        if !isempty(setdiff(sort([f.name for f in files]), sort(first.(out_files))))
            success = false
            @warn "Unexpected output files present" setdiff(sort([f.name for f in files]), sort(first.(out_files)))
        end
        if !isempty(out_files)
            @debug "Copying files from $tmp_dir to $original_dir" out_files readdir(tmp_dir)
            for (from, to) in out_files
                if !isfile(joinpath(tmp_dir, from))
                    success = false
                    @warn "Expected output file not present" from
                    continue
                end
                if to != nothing
                    cp(joinpath(tmp_dir, from), joinpath(original_dir, to), force=out_files_overwrite)
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
inputlines(log::String) = filter(s -> !isempty(s) && !startswith(s, "! "), split(log, "\n"))
outputlines(res::ExecutionResult) = outputlines(res.log)
outputlines(log::String) = map(s -> strip(s[2:end]), filter(s -> startswith(s, "! "), split(log, "\n")))

inout_pairs(res::ExecutionResult) = inout_pairs(res.log)
function inout_pairs(log::String)
    lines = map(s -> (line=s, kind=startswith(s, "! ") ? :out : :in), split(log, "\n"))
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
