# Overview

Julia wrapper for the [difmap](ftp://ftp.astro.caltech.edu/pub/difmap/) program.
Conveniently execute difmap scripts, handle input/output files and logs.
Relies on the `difmap_jll.jl` package to provide the `difmap` binary.

# Usage

```julia
julia> using Difmap

julia> script = [
          "print(1 + 2)",
          "exit",
       ];

julia> res = Difmap.execute(script);

julia> res.success
true

julia> Difmap.inout_pairs(res)[begin+1:end-1]  # first and last lines contain current time
1-element Vector{Pair{String, Vector{String}}}:
 "print(1 + 2)" => ["3"]
```

```julia
julia> script = [
           "observe vis.fits",
           "select I",
           "mapsize 512, 0.2",
           "clean 500",
           "restore",
           "device tmp.ps/PS",
           "mapplot cln",
           "save result",
           "exit",
       ];


julia> vis_file = joinpath(dirname(dirname(pathof(Difmap))), "test/data/vis.fits");

julia> res = Difmap.execute(script,
           in_files=[vis_file => "vis.fits"],
           out_files=["result.fits", "result.mod", "result.par", "result.uvf", "tmp.ps"] .=> nothing,  # target is nothing - ignore these files
       );

julia> res.success
true

julia> Difmap.inout_pairs(res)[begin+1:end-1]  # first and last lines contain current time
8-element Vector{Pair{String, Vector{String}}}:
 "observe vis.fits" => ["Reading UV FITS file: vis.fits", "AN table 1: 4 integrations on 36 of 36 possible baselines.", "Apparent sampling: 1 visibilities/baseline/integration-bin.", "Found source: J0000+0248", "", "There are 8 IFs, and a total of 8 channels:", "", "IF  Channel    Frequency  Freq offset  Number of   Overall IF", "origin    at origin  per channel   channels    bandwidth", "------------------------------------------------------------- (Hz)"  …  "05        5    4.416e+09      3.2e+07          1      3.2e+07", "06        6    4.512e+09      3.2e+07          1      3.2e+07", "07        7    4.544e+09      3.2e+07          1      3.2e+07", "08        8    4.576e+09      3.2e+07          1      3.2e+07", "", "Polarization(s): RR", "", "Read 0 lines of history.", "", "Reading 1152 visibilities."]
         "select I" => ["Polarization I is unavailable.", "Selecting polarization: RR,  channels: 1..8", "Reading IF 1 channels: 1..1", "Reading IF 2 channels: 2..2", "Reading IF 3 channels: 3..3", "Reading IF 4 channels: 4..4", "Reading IF 5 channels: 5..5", "Reading IF 6 channels: 6..6", "Reading IF 7 channels: 7..7", "Reading IF 8 channels: 8..8"]
 "mapsize 512, 0.2" => ["Map grid = 512x512 pixels with 0.200x0.200 milli-arcsec cellsize."]
        "clean 500" => ["Inverting map and beam", "Estimated beam: bmin=1.195 mas, bmaj=3.79 mas, bpa=-3.012 degrees", "Estimated noise=0.541101 mJy/beam.", "clean: niter=500  gain=0.05  cutoff=0", "Component: 050  -  total flux cleaned = 0.0188812 Jy", "Component: 100  -  total flux cleaned = 0.0252178 Jy", "Component: 150  -  total flux cleaned = 0.0277823 Jy", "Component: 200  -  total flux cleaned = 0.0290343 Jy", "Component: 250  -  total flux cleaned = 0.0300524 Jy", "Component: 300  -  total flux cleaned = 0.0302839 Jy", "Component: 350  -  total flux cleaned = 0.0304884 Jy", "Component: 400  -  total flux cleaned = 0.0304353 Jy", "Component: 450  -  total flux cleaned = 0.0305383 Jy", "Component: 500  -  total flux cleaned = 0.030393 Jy", "Total flux subtracted in 500 components = 0.030393 Jy", "Clean residual min=-0.000455 max=0.000452 Jy/beam", "Clean residual mean=0.000001 rms=0.000189 Jy/beam", "Combined flux in latest and established models = 0.030393 Jy"]
          "restore" => ["restore: Substituting estimate of restoring beam from last 'invert'.", "Restoring with beam: 1.195 x 3.79 at -3.012 degrees (North through East)", "Clean map  min=-0.0010866  max=0.019272 Jy/beam"]
 "device tmp.ps/PS" => ["Attempting to open device: 'tmp.ps/PS'"]
      "mapplot cln" => []
      "save result" => ["Writing UV FITS file: result.uvf", "Writing 174 model components to file: result.mod", "Adding 174 model components to the UV plane model.", "The established model now contains 174 components and 0.030393 Jy", "Inverting map", "restore: Substituting estimate of restoring beam from last 'invert'.", "Restoring with beam: 1.195 x 3.79 at -3.012 degrees (North through East)", "Clean map  min=-0.0010295  max=0.019271 Jy/beam", "Writing clean map to FITS file: result.fits", "Writing difmap environment to: result.par"]
```
