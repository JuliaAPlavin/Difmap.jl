using Test
using Pkg.Artifacts
using Difmap


let
    artifact_toml = joinpath(@__DIR__, "Artifacts.toml")
    art_hash = artifact_hash("test_data", artifact_toml)
    if art_hash === nothing || !artifact_exists(art_hash)
        @info "Creating artifact"
        art_hash_new = create_artifact() do artifact_dir
            for url in [
                    "http://astrogeo.org/images/J0000+0248/J0000+0248_C_2016_01_03_pet_vis.fits",
                ]
                download(url, joinpath(artifact_dir, basename(url)))
            end
        end
        if art_hash == nothing
            bind_artifact!(artifact_toml, "test_data", art_hash_new, force=true)
        else
            @assert art_hash == art_hash_new
        end
    end
end


@testset "execute" begin
    script = [
        "print(1 + 2)",
        "exit",
    ]
    res = Difmap.execute(script)
    @test res.success
    @test isempty(res.outfiles)
    @test res.stderr == "Exiting program\n"
    @test Difmap.inputlines(res) == script
    @test Difmap.outputlines(res) |> length == 4
    @test occursin("Started logfile", Difmap.outputlines(res)[1])
    @test Difmap.outputlines(res)[2] == "3"
    @test occursin("Exiting program", Difmap.outputlines(res)[3])
    @test occursin("difmap.log closed", Difmap.outputlines(res)[4])
    @test Difmap.inout_pairs(res) |> length == length(script) + 1
    @test Difmap.inout_pairs(res)[2] == ("print(1 + 2)" => ["3"])
end

@testset "copy file" begin
    res = mktemp() do tempf, _
        write(tempf, "\nprint \"2 * 2\"\n")
        script = [
            "print(1 + 2)",
            "@my_script_file",
            "exit",
        ]
        Difmap.execute(script, source_files=[tempf => "my_script_file"])
    end
    @test res.success
    @test isempty(res.outfiles)
    @test res.stderr == "Exiting program\n"
    @test Difmap.outputlines(res) |> length == 5
    @test occursin("Started logfile", Difmap.outputlines(res)[1])
    @test Difmap.outputlines(res)[2] == "3"
    @test "2 * 2" == Difmap.outputlines(res)[3]
    @test Difmap.inout_pairs(res) |> length == 6
    @test Difmap.inout_pairs(res)[2] == ("print(1 + 2)" => ["3"])
    @test Difmap.inout_pairs(res)[3] == ("![@my_script_file]" => [])
    @test Difmap.inout_pairs(res)[4] == ("print \"2 * 2\"" => ["2 * 2"])
end

@testset "process vis data" begin
    script = [
        "observe $(joinpath(artifact"test_data", "J0000+0248_C_2016_01_03_pet_vis.fits"))",
        "select I",
        "mapsize 512, 0.2",
        "clean 500",
        "restore",
        "device tmp.ps/PS",
        "mapplot cln",
        "save result",
        "exit",
    ]
    @test_throws AssertionError Difmap.execute(script)
    res = Difmap.execute(script, target_files=["result.fits", "result.mod", "result.par", "result.uvf", "tmp.ps"] .=> nothing)
    @test res.success
    @test res.outfiles == [
        (name = "result.fits", size = 279360),
        (name = "result.mod", size = 7026),
        (name = "result.par", size = 635),
        (name = "result.uvf", size = 43200),
        (name = "tmp.ps", size = 234289),
    ]
    @test res.stderr == "Polarization I is unavailable.\nExiting program\n"
    iops = Difmap.inout_pairs(res)
    @test length(iops) == length(script) + 1
    @test occursin(r"^AN table", iops[2].second[2])
    @test occursin(r" J0000\+0248$", iops[2].second[4])
    @test occursin(" 1152 visibilities", iops[2].second[end])
    @test occursin(" = 512x512 pixels ", iops[4].second[end])
end
