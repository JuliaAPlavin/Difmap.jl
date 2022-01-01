using Test
using Difmap


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
        Difmap.execute(script, in_files=[tempf => "my_script_file"])
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
        "observe $(joinpath(@__DIR__, "./data/vis.fits"))",
        "select I",
        "mapsize 512, 0.2",
        "clean 500",
        "restore",
        "device tmp.ps/PS",
        "mapplot cln",
        "save result",
        "exit",
    ]
    @test_logs (:warn,) res = Difmap.execute(script)
    @test !res.success
    res = Difmap.execute(script, out_files=["result.fits", "result.mod", "result.par", "result.uvf", "tmp.ps"] .=> nothing)
    @test res.success
    @test res.outfiles[[1, 2, 4]] == [
        (name = "result.fits", size = 279360),
        (name = "result.mod", size = 7026),
        (name = "result.uvf", size = 43200),
    ]
    @test res.outfiles[end].name == "tmp.ps"
    @test res.stderr == "Polarization I is unavailable.\nExiting program\n"
    iops = Difmap.inout_pairs(res)
    @test length(iops) == length(script) + 1
    @test occursin(r"^AN table", iops[2].second[2])
    @test occursin(r" J0000\+0248$", iops[2].second[4])
    @test occursin(" 1152 visibilities", iops[2].second[end])
    @test occursin(" = 512x512 pixels ", iops[4].second[end])
end


using Documenter
doctest(Difmap; manual=false)

import CompatHelperLocal as CHL
CHL.@check()
