# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "difmap"
version = v"2.5.500"

sources = [
    ArchiveSource("ftp://ftp.astro.caltech.edu/pub/difmap/difmap2.5e.tar.gz", "457cd77c146e22b5332403c19b29485388a863ec494fff87137176396fc6a9ff"),
    ArchiveSource("ftp://ftp.astro.caltech.edu/pub/pgplot/pgplot5.2.tar.gz", "a5799ff719a510d84d26df4ae7409ae61fe66477e3f1e8820422a9a4727a5be4")
]

script = raw"""
cd $WORKSPACE/srcdir
mkdir pgplot_build && cd pgplot_build/
cat ../pgplot/drivers.list | sed 's|! PSDRIV|  PSDRIV|g' | sed 's|! GIDRIV|  GIDRIV|g' > drivers.list
../pgplot/makemake ../pgplot/ linux g77_gcc
sed -i 's|FCOMPL=g77|FCOMPL=gfortran|' makefile
make && make clean
cd ../uvf_difmap/
sed -i 's|^PGPLOT_LIB="-lpgplot -lX11"|PGPLOT_LIB="-L/workspace/srcdir/pgplot_build -L/usr/X11R6/lib -Xlinker -R/workspace/srcdir/pgplot_build:/usr/X11R6/lib -lpgplot -lX11"|' configure
sed -i 's|^USE_TECLA="1"|USE_TECLA="0"|' configure
./configure linux-i486-gcc
./makeall
cp ./difmap $bindir
cp ../pgplot_build/libpgplot.so $libdir
"""

platforms = [
    Linux(:x86_64, libc=:musl),
    Linux(:x86_64, libc=:glibc),
]
platforms = expand_gfortran_versions(platforms)

products = [
    LibraryProduct("libpgplot", :libpgplot),
    ExecutableProduct("difmap", :difmap)
]

dependencies = [
    Dependency(PackageSpec(name="Xorg_libX11_jll", uuid="4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"))
    Dependency(PackageSpec(name="Ncurses_jll", uuid="68e3532b-a499-55ff-9963-d1c0c0748b3a"))
    Dependency(PackageSpec(name="CompilerSupportLibraries_jll", uuid="e66e0078-7015-5450-92f7-15fbd957f2ae"))
]

build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)
