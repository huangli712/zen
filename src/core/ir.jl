#
# project : pansy
# source  : ir.jl
# author  : Li Huang (lihuang.dmft@gmail.com)
# status  : unstable
# comment :
#
# last modified: 2021/01/26
#

#
# Driver Functions
#

"""
    ir_adaptor()

Write the Kohn-Data data to specified files using the IR format.
"""
function ir_adaptor()
    # S01: Print the header
    println("  < IR Adaptor >")

    # S02: Write lattice structure
    println("    Put Lattice")
    if haskey(DFTData, "latt")
        irio_lattice(pwd(), DFTData["latt"])
    else
        error("The DFTData dict does not contain the key: latt")
    end

    # S03: Write kmesh and the corresponding weights
    println("    Put Kmesh")
    println("    Put Weight")
    if haskey(DFTData, "kmesh") && haskey(DFTData, "weight")
        irio_kmesh(pwd(), DFTData["kmesh"], DFTData["weight"])
    else
        error("The DFTData dict does not contain the keys: kmesh and weight")
    end

#
# Remarks:
#
# This step is optional, because the tetrahedron information might
# be absent.
#

    # S04: Write tetrahedron data if they are available
    if get_d("smear") === "tetra"
        println("    Put Tetrahedron")
        if haskey(DFTData, "volt") && haskey(DFTData, "itet")
            irio_tetra(pwd(), DFTData["volt"], DFTData["itet"])
        else
            error("The DFTData dict does not contain the keys: volt and itet")
        end
    end

    # S05: Write band structure and the corresponding occupancies
    println("    Put Enk")
    println("    Put Occupy")
    if haskey(KohnShamData, "enk") && haskey(KohnShamData, "occupy")
        irio_eigen(pwd(), KohnShamData["enk"], KohnShamData["occupy"])
    else
        error("The KohnShamData dict does not contain the keys: enk and occupy")
    end

    # S06: Write projectors, traits, and groups
    println("    Put Projector (Trait and Group)")
    if haskey(KohnShamData, "chipsi")
        irio_projs(pwd(), KohnShamData["chipsi"])
    else
        error("The KohnShamData dict does not contain the key: chipsi")
    end

    # S07: Write fermi level
    println("    Put Fermi Level")
    if haskey(KohnShamData, "fermi")
        irio_fermi(pwd(), KohnShamData["fermi"])
    else
        error("The KohnShamData dict does not contain the key: fermi")
    end
end

#
# Service Functions
#

"""
    irio_lattice(f::String, latt::Lattice)

Write the lattice information to lattice.ir using the IR format. Here `f`
means only the directory that we want to use.
"""
function irio_lattice(f::String, latt::Lattice)
    # Extract some key parameters
    _case, scale, nsort, natom = latt._case, latt.scale, latt.nsort, latt.natom

    # Output the data
    open(joinpath(f, "lattice.ir"), "w") do fout
        # Write the header
        println(fout, "# file: lattice.ir")
        println(fout, "# data: Lattice struct")
        println(fout)
        println(fout, "scale -> $_case")
        println(fout, "scale -> $scale")
        println(fout, "nsort -> $nsort")
        println(fout, "natom -> $natom")
        println(fout)

        # Write the body
        # For sorts part
        println(fout, "[sorts]")
        for i = 1:nsort # Symbols
            @printf(fout, "%6s", latt.sorts[i, 1])
        end
        println(fout)
        for i = 1:nsort # Numbers
            @printf(fout, "%6i", latt.sorts[i, 2])
        end
        println(fout)
        println(fout)

        # For atoms part
        println(fout, "[atoms]")
        for i = 1:natom
            @printf(fout, "%6s", latt.atoms[i])
        end
        println(fout)
        println(fout)

        # For lvect part
        println(fout, "[lvect]")
        for i = 1:3
            @printf(fout, "%16.12f %16.12f %16.12f\n", latt.lvect[i, 1:3]...)
        end
        println(fout)

        # For coord part
        println(fout, "[coord]")
        for i = 1:natom
            @printf(fout, "%16.12f %16.12f %16.12f\n", latt.coord[i, 1:3]...)
        end
    end
end

"""
    irio_kmesh(f::String, kmesh::Array{F64,2}, weight::Array{F64,1})

Write the kmesh and weight information to kmesh.ir using the IR format. Here
`f` means only the directory that we want to use.
"""
function irio_kmesh(f::String, kmesh::Array{F64,2}, weight::Array{F64,1})
    # Extract some key parameters
    nkpt, ndir = size(kmesh)

    # Extract some key parameters
    _nkpt, = size(weight)

    # Sanity check
    @assert nkpt === _nkpt

    # Output the data
    open(joinpath(f, "kmesh.ir"), "w") do fout
        # Write the header
        println(fout, "# file: kmesh.ir")
        println(fout, "# data: kmesh[nkpt,ndir] and weight[nkpt]")
        println(fout)
        println(fout, "nkpt -> $nkpt")
        println(fout, "ndir -> $ndir")
        println(fout)

        # Write the body
        for k = 1:nkpt
            @printf(fout, "%16.12f %16.12f %16.12f %8.2f\n", kmesh[k, 1:3]..., weight[k])
        end
    end
end

"""
    irio_tetra(f::String, volt::F64, itet::Array{I64,2})

Write the tetrahedra information to tetra.ir using the IR format. Here `f`
means only the directory that we want to use.
"""
function irio_tetra(f::String, volt::F64, itet::Array{I64,2})
    # Extract some key parameters
    ntet, ndim = size(itet)

    # Sanity check
    @assert ndim === 5

    # Output the data
    open(joinpath(f, "tetra.ir"), "w") do fout
        # Write the header
        println(fout, "# file: tetra.ir")
        println(fout, "# data: itet[ntet,5]")
        println(fout)
        println(fout, "ntet -> $ntet")
        println(fout, "volt -> $volt")
        println(fout)

        # Write the body
        for t = 1:ntet
            @printf(fout, "%8i %8i %8i %8i %8i\n", itet[t, :]...)
        end
    end
end

"""
    irio_eigen(f::String, enk::Array{F64,3}, occupy::Array{F64,3})

Write the eigenvalues to eigen.ir using the IR format. Here `f` means only
the directory that we want to use.
"""
function irio_eigen(f::String, enk::Array{F64,3}, occupy::Array{F64,3})
    # Extract some key parameters
    nband, nkpt, nspin = size(enk)

    # Extract some key parameters
    _nband, _nkpt, _nspin = size(enk)

    # Sanity check
    @assert nband === _nband && nkpt === _nkpt && nspin === _nspin

    # Output the data
    open(joinpath(f, "eigen.ir"), "w") do fout
        # Write the header
        println(fout, "# file: eigen.ir")
        println(fout, "# data: enk[nband,nkpt,nspin] and occupy[nband,nkpt,nspin]")
        println(fout)
        println(fout, "nband -> $nband")
        println(fout, "nkpt  -> $nkpt ")
        println(fout, "nspin -> $nspin")
        println(fout)

        # Write the body
        for s = 1:nspin
            for k = 1:nkpt
                for b = 1:nband
                    @printf(fout, "%16.12f %16.12f\n", enk[b, k, s], occupy[b, k, s])
                end
            end
        end
    end
end

"""
    irio_projs(f::String, chipsi::Array{C64,4})

Write the projectors to projs.ir using the IR format. Here `f` means only
the directory that we want to use.
"""
function irio_projs(f::String, chipsi::Array{C64,4})
    # Extract some key parameters
    nproj, nband, nkpt, nspin = size(chipsi)

    # Output the data
    open(joinpath(f, "projs.ir"), "w") do fout
        # Write the header
        println(fout, "# file: projs.ir")
        println(fout, "# data: chipsi[nproj,nband,nkpt,nspin]")
        println(fout)
        println(fout, "nproj -> $nproj")
        println(fout, "nband -> $nband")
        println(fout, "nkpt  -> $nkpt ")
        println(fout, "nspin -> $nspin")
        println(fout)

        # Write the body
        for s = 1:nspin
            for k = 1:nkpt
                for b = 1:nband
                    for p = 1:nproj
                        _re = real(chipsi[p, b, k, s])
                        _im = imag(chipsi[p, b, k, s])
                        @printf(fout, "%16.12f %16.12f\n", _re, _im)
                    end
                end
            end
        end
    end
end

"""
    irio_fermi(f::String, fermi::F64)

Write the fermi level to fermi.ir using the IR format. Here `f` means only
the directory that we want to use.
"""
function irio_fermi(f::String, fermi::F64)
    # Output the data
    open(joinpath(f, "fermi.ir"), "w") do fout
        # Write the header
        println(fout, "# file: fermi.ir")
        println(fout, "# data: fermi")
        println(fout)
        println(fout, "fermi -> $fermi")
        println(fout)

        # Write the body
        # N/A
    end
end

"""
    irio_charge(f::String)

Write the charge density to charge.ir using the IR format. Here `f` means
only the directory that we want to use.
"""
function irio_charge(f::String) end
