#
# Project : Pansy
# Source  : dmft.jl
# Author  : Li Huang (lihuang.dmft@gmail.com)
# Status  : Unstable
#
# Last modified: 2021/03/30
#

"""
    dmft_init(it::IterInfo, task::I64)

Initialize the dynamical mean-field theory engine. Prepare the necessary
files, and generate the configuration file.

See also: [`dmft_exec`](@ref), [`dmft_save`](@ref).
"""
function dmft_init(it::IterInfo, task::I64)
    # Check the task
    @assert task in (1, 2) 

    # Well, determine which files are necessary. They are defined in
    # `fsig`, `fir`, and `fdmft`.
    #
    # Self-energy functions
    fsig = ["sigma.bare", "sigma.dc"]
    #
    # Kohn-Sham data (including projectors) in IR format
    fir  = ["params.ir", "groups.ir", "lattice.ir", "kmesh.ir", "eigen.ir", "projs.ir"]
    if get_d("smear") === "tetra"
        push!(fir, "tetra.ir")
    end
    #
    # Configuration file for DMFT engine
    fdmft = ("dmft.in")

    # Next, we have to copy Kohn-Sham data from `dft` to `dmft1`.
    for i in eachindex(fir)
        file_src = joinpath("../dft", fir[i])
        file_dst = fir[i]
        cp(file_src, file_dst, force = true)
    end

    # Extract key parameters
    axis = get_m("axis")
    beta = get_m("beta")
    lfermi = true
    ltetra = ( get_d("smear") === "tetra" )

    # Generate essential input files, such as dmft.in, dynamically.
    # If the `dmft.in` file exists already, it will be overwritten.
    open("dmft.in", "w") do fout
        println(fout, "task = $task")
        println(fout, "axis = $axis")
        println(fout, "beta = $beta")
        println(fout, "lfermi = $lfermi")
        println(fout, "ltetra = $ltetra")
    end

    # Check essential input files
    flist = (fdmft, fsig..., fir...)
    for i in eachindex(flist)
        filename = flist[i]
        if !isfile(filename)
            error("Please make sure the file $filename is available")
        end
    end
end

"""
    dmft_exec(it::IterInfo)

Execute the dynamical mean-field theory engine.

See also: [`dmft_init`](@ref), [`dmft_save`](@ref).
"""
function dmft_exec(it::IterInfo)
    # Print the header
    println("Engine : DMFT1")

    # Get the home directory of Zen
    zen_home = query_home()

    # Determine mpi prefix (whether the dmft is executed sequentially)
    mpi_prefix = inp_toml("../MPI.toml", "dmft", false)
    numproc = parse(I64, line_to_array(mpi_prefix)[3])
    println("  Para : Using $numproc processors")

    # Select suitable dmft program
    dmft_exe = "$zen_home/src/dmft/dmft"
    @assert isfile(dmft_exe)
    println("  Exec : $dmft_exe")

    # Assemble command
    if isnothing(mpi_prefix)
        dmft_cmd = dmft_exe
    else
        dmft_cmd = split("$mpi_prefix $dmft_exe", " ")
    end

    # Launch it, the terminal output is redirected to dmft.out
    run(pipeline(`$dmft_cmd`, stdout = "dmft.out"))

    # Print the footer
    println()
end

"""
    dmft_save(it::IterInfo)

See also: [`dmft_init`](@ref), [`dmft_exec`](@ref).
"""
function dmft_save(it::IterInfo)
end
