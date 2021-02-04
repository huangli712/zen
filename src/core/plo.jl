#
# project : pansy
# source  : plo.jl
# author  : Li Huang (lihuang.dmft@gmail.com)
# status  : unstable
# comment :
#
# last modified: 2021/02/04
#

#
# Driver Functions
#

"""
    plo_adaptor(D::Dict{Symbol,Any}, debug::Bool = false)

Adaptor support. It will postprocess the raw projector matrix. The dict
D contains all of the necessary Kohn-Sham data, which will be modified
in this function.
"""
function plo_adaptor(D::Dict{Symbol,Any}, debug::Bool = false)
    # P01: Print the header
    println("  < PLO Adaptor >")

    # P02: Check the validity of the original dict
    key_list = [:enk, :fermi, :chipsi, :PG]
    for k in key_list
        @assert haskey(D, k)
    end

    # P03: Adjust the band structure
    #
    # D[:fermi] will be updated
    println("    Calibrate Fermi Level")
    plo_fermi(D[:enk], D[:fermi])

    # P04: Setup the PrGroup strcut further
    #
    # D[:PG] will be updated
    println("    Complete Groups")
    plo_group(D[:PG])

    # P05: Setup the band / energy window for projectors
    #
    # D[:PW] will be created
    println("    Generate Window")
    D[:PW] = plo_window(D[:PG], D[:enk])

    # P06: Transform the projector matrix
    #
    # D[:chipsi_r] will be created
    println("    Rotate Projectors")
    D[:chipsi_r] = plo_rotate(D[:PG], D[:chipsi])

    # P07: Filter the projector matrix
    #
    # D[:chipsi_f] will be created
    println("    Filter Projectors")
    D[:chipsi_f] = plo_filter(D[:PW], D[:chipsi_r])

    # P08: To make sure the projectors orthogonalize with each other
    #
    # D[:chipsi_f] will be updated
    println("    Normalize Projectors")
    plo_orthog(D[:PW], D[:chipsi_f])

    # P09: Write the density matrix and overlap matrix for checking
    if debug
        println("DEBUG!")
        dm = calc_dm(D[:PW], D[:chipsi_f], D[:weight], D[:occupy])
        view_dm(D[:PG], dm)
        ovlp = calc_ovlp(D[:PW], D[:chipsi_f], D[:weight])
        view_ovlp(D[:PG], ovlp)
        hamk = calc_hamk(D[:PW], D[:chipsi_f], D[:weight], D[:enk])
        view_hamk(D[:PG], hamk)
        #calc_dos(D[:PW], D[:chipsi_f], D[:itet], D[:enk])
    end
end

#
# Service Functions (Group A)
#

"""
    plo_group(PG::Array{PrGroup,1})

Use the information contained in the PIMP dict to further complete
the PrGroup struct.
"""
function plo_group(PG::Array{PrGroup,1})

#
# Remarks:
#
# 1. Until now, the PG array was only created in vasp.jl/vaspio_projs().
#
# 2. In this function, `corr`, `shell`,  and `Tr` which are members of
#    PrGroup struct will be modified according to users' configuration
#    in other words, the case.toml file.
#

    # Additional check for the parameters contained in PIMP dict
    @assert get_i("nsite") === length(get_i("atoms"))
    @assert get_i("nsite") === length(get_i("shell"))

    # The lshell creates a mapping from shell (string) to l (integer).
    # It is used to parse get_i("shell") to extract the `l` parameter.
    lshell = Dict{String,I64}(
                 "s"     => 0,
                 "p"     => 1,
                 "d"     => 2,
                 "f"     => 3,
                 "d_t2g" => 2, # Only a subset of d orbitals
                 "d_eg"  => 2, # Only a subset of d orbitals
             )

    # Loop over each site (the quantum impurity problem) to gather some
    # relevant information, such as `site` and `l`. We use a Array of
    # Tuple (site_l) to record them.
    site_l = Tuple[]
    for i = 1:get_i("nsite")
        # Determine site
        str = get_i("atoms")[i]
        site = parse(I64, line_to_array(str)[3])

        # Determine l and its specification
        str = get_i("shell")[i]
        l = get(lshell, str, nothing)

        # Push the data into site_l
        push!(site_l, (site, l, str))
    end

    # Scan the groups of projectors, setup them one by one.
    for g in eachindex(PG)
        # Examine PrGroup, check number of projectors
        @assert 2 * PG[g].l + 1 === length(PG[g].Pr)

        # Loop over each site (quantum impurity problem)
        for i in eachindex(site_l)
            SL = site_l[i]
            # Well, find out the required PrGroup
            if (PG[g].site, PG[g].l) === (SL[1], SL[2])
                # Setup corr property
                PG[g].corr = true

                # Setup shell property. Later it will be used to generate `Tr`
                PG[g].shell = SL[3]
            end
        end

        # Setup Tr array further
        @cswitch PG[g].shell begin
            @case "s"
                PG[g].Tr = Matrix{ComplexF64}(I, 1, 1)
                break

            @case "p"
                PG[g].Tr = Matrix{ComplexF64}(I, 3, 3)
                break

            @case "d"
                PG[g].Tr = Matrix{ComplexF64}(I, 5, 5)
                break

            @case "f"
                PG[g].Tr = Matrix{ComplexF64}(I, 7, 7)
                break

            @case "d_t2g"
                PG[g].Tr = zeros(C64, 3, 5)
                PG[g].Tr[1, 1] = 1.0 + 0.0im
                PG[g].Tr[2, 2] = 1.0 + 0.0im
                PG[g].Tr[3, 4] = 1.0 + 0.0im
                break

            @case "d_eg" # TO_BE_CHECK
                PG[g].Tr = zeros(C64, 2, 5)
                PG[g].Tr[1, 3] = 1.0 + 0.0im
                PG[g].Tr[2, 5] = 1.0 + 0.0im
                break

            @default
                sorry()
                break
        end
    end
end

"""
    plo_fermi(enk::Array{F64,3}, fermi::F64)

Calibrate the band structure to enforce the fermi level to be zero.
"""
function plo_fermi(enk::Array{F64,3}, fermi::F64)
    @. enk = enk - fermi
end

"""
    plo_window(PG::Array{PrGroup,1}, enk::Array{F64,3})

Calibrate the band window to filter the Kohn-Sham eigenvalues.
"""
function plo_window(PG::Array{PrGroup,1}, enk::Array{F64,3})

#
# Remarks:
#
# Here, `window` means energy window or band window. When nwin is 1, it
# means that all PrGroup share the same window. When nwin is equal to
# length(PG), it means that each PrGroup should have its own window.
#

    # Preprocess the input. Get how many windows there are.
    window = get_d("window")
    nwin = convert(I64, length(window) / 2)

    # Sanity check
    @assert nwin === 1 || nwin === length(PG)

    # Initialize an array of PrWindow struct
    PW = PrWindow[]

    # Scan the groups of projectors, setup PrWindow for them.
    for p in eachindex(PG)
        # Determine bwin. Don't forget it is a Tuple. bwin = (emin, emax).
        if nwin === 1
            # All PrGroup shares the same window
            bwin = (window[1], window[2])
        else
            # Each PrGroup has it own window
            bwin = (window[2*p-1], window[2*p])
        end

        # Examine bwin further. Its elements should obey the order. This
        # window must be defined by band indices (they are integers) or
        # energies (two float numbers).
        @assert bwin[2] > bwin[1]
        @assert typeof(bwin[1]) === typeof(bwin[2])
        @assert bwin[1] isa Integer || bwin[1] isa AbstractFloat

        # The `bwin` is only the global window. But we actually need a
        # momentum-dependent and spin-dependent window. This is `kwin`.
        if bwin[1] isa Integer
            kwin = get_win1(enk, bwin)
        else
            kwin = get_win2(enk, bwin)
        end

        # Create the PrWindow struct, and push it into the PW array.
        push!(PW, PrWindow(kwin, bwin))
    end

    # Return the desired arrays
    return PW
end

"""
    plo_rotate(PG::Array{PrGroup,1}, chipsi::Array{C64,4})

Perform global rotations or transformations for the projectors.
"""
function plo_rotate(PG::Array{PrGroup,1}, chipsi::Array{C64,4})
    # Extract some key parameters from raw projector matrix
    nproj, nband, nkpt, nspin = size(chipsi)

    # Initialize new array. It stores the rotated projectors.
    # Now it is empty, but we will allocate memory for it later.
    chipsi_r = Array{C64,4}[]

#
# Remarks:
#
# PG[i].Tr must be a matrix. Its size must be (ndim, p2 - p1 + 1).
#

    # Go through each PrGroup and perform the rotation
    for i in eachindex(PG)
        # Determine the range of original projectors
        p1 = PG[i].Pr[1]
        p2 = PG[i].Pr[end]

        # Determine the number of projectors after rotation
        ndim = size(PG[i].Tr)[1]

        # Create a temporary array M
        M = zeros(C64, ndim, nband, nkpt, nspin)

        # Rotate chipsi by Tr, the results are stored at M.
        for s = 1:nspin
            for k = 1:nkpt
                for b = 1:nband
                    M[:, b, k, s] = PG[i].Tr * chipsi[p1:p2, b, k, s]
                end
            end
        end

        # Push M into chipsi_r to save it
        push!(chipsi_r, M)
    end

    # Return the desired arrays
    return chipsi_r
end

"""
    plo_filter(PW::Array{PrWindow,1}, chipsi::Array{Array{C64,4},1}}

Filter the projector matrix according to band window.
"""
function plo_filter(PW::Array{PrWindow,1}, chipsi::Array{Array{C64,4},1})
    # Initialize new array. It stores the filtered projectors.
    # Now it is empty, but we will allocate memory for it later.
    chipsi_f = Array{C64,4}[]

    # Go through each PrWindow
    for p in eachindex(PW)
        # Extract some key parameters
        ndim, nband, nkpt, nspin = size(chipsi[p])

        # Create a temporary array M
        M = zeros(C64, ndim, PW[p].nbnd, nkpt, nspin)

        # Go through each spin and k-point
        for s = 1:nspin
            for k = 1:nkpt
                # Select projectors which live in the given band window
                # `ib1` and `ib2` are the boundaries.
                ib1 = PW[p].kwin[k, s, 1]
                ib2 = PW[p].kwin[k, s, 2]

                # `ib3` are total number of bands for given `s` and `k`
                ib3 = ib2 - ib1 + 1

                # Sanity check
                @assert ib3 <= PW[p].nbnd

                # We just copy data from chipsi to M
                M[:, 1:ib3, k, s] = chipsi[p][:, ib1:ib2, k, s]
            end
        end

        # Push M into chipsi_f
        push!(chipsi_f, M)
    end

    # Return the desired arrays
    return chipsi_f
end

"""
    plo_orthog(PW::Array{PrWindow,1}, chipsi::Array{Array{C64,4},1})

Try to orthogonalize the projectors group by group.
"""
function plo_orthog(PW::Array{PrWindow,1}, chipsi::Array{Array{C64,4},1})
    for p in eachindex(PW)
        # Extract some key parameters
        ndim, nbnd, nkpt, nspin = size(chipsi[p])
        @assert nbnd === PW[p].nbnd

        # Loop over spins and kpoints
        for s = 1:nspin
            for k = 1:nkpt
                # Determine band index and band window
                ib1 = PW[p].kwin[k, s, 1]
                ib2 = PW[p].kwin[k, s, 2]
                ib3 = ib2 - ib1 + 1

                # Make a view for the desired subarray
                M = view(chipsi[p], 1:ndim, 1:ib3, k, s)

                # Orthogonalize it (chipsi is update at the same time)
                try_diag(M)
            end
        end
    end
end

#
# Service Functions (Group B)
#

"""
    get_win1(enk::Array{F64,3}, bwin::Tuple{I64,I64})

Return momentum- and spin-dependent band window.
"""
function get_win1(enk::Array{F64,3}, bwin::Tuple{I64,I64})
    # Here, bwin defines the global band window.
    bmin, bmax = bwin

    # Extract some key parameters
    nband, nkpt, nspin = size(enk)

    # Create array kwin, which is used to record the band window for
    # each kpt and each spin.
    kwin = zeros(I64, nkpt, nspin, 2)

    # Fill kwin with global band boundaries
    fill!(kwin[:, :, 1], bmin)
    fill!(kwin[:, :, 2], bmax)

    # Return the desired array
    return kwin
end

"""
    get_win2(enk::Array{F64,3}, bwin::Tuple{F64,F64})

Return momentum- and spin-dependent band window.
"""
function get_win2(enk::Array{F64,3}, bwin::Tuple{F64,F64})
    # Here, bwin defines the global energy window
    emin, emax = bwin

    # Sanity check. We should make sure there is an overlap between
    # [emin, emax] and band structure.
    if emax < minimum(enk) || emin > maximum(enk)
        error("Energy window does not overlap with the band structure")
    end

    # Extract some key parameters
    nband, nkpt, nspin = size(enk)

    # Create array kwin, which is used to record the band window for
    # each kpt and each spin.
    kwin = zeros(I64, nkpt, nspin, 2)

    # Scan the band structure to determine kwin
    for s = 1:nspin
        for k = 1:nkpt
            # For lower boundary
            ib1 = 1
            while enk[ib1, k, s] < emin
                ib1 = ib1 + 1
            end

            # For upper boundary
            ib2 = nband
            while enk[ib2, k, s] > emax
                ib2 = ib2 - 1
            end

            # Check the boundaries
            @assert ib1 <= ib2

            # Save the boundaries. The ib1 and ib2 mean the lower and
            # upper boundaries, respectively.
            kwin[k, s, 1] = ib1
            kwin[k, s, 2] = ib2
        end
    end

    # Return the desired array
    return kwin
end

"""
    try_diag(M::AbstractArray{C64,2})

Orthogonalize the given matrix.
"""
function try_diag(M::AbstractArray{C64,2})
    # Calculate overlap matrix, it must be a hermitian matrix.
    ovlp = M * M'
    @assert ishermitian(ovlp)

    # Diagonalize the overlap matrix, return eigenvalues and eigenvectors.
    vals, vecs = eigen(Hermitian(ovlp))
    @assert all(vals .> 0)

    # Calculate the renormalization factor
    sqrt_vals = map(x -> 1.0 / sqrt(x), vals)
    S = vecs * Diagonal(sqrt_vals) * vecs'

    # Renormalize the input matrix
    copy!(M, S * M)
end

#
# Service Functions (Group C)
#

"""
    calc_ovlp(chipsi::Array{C64,4}, weight::Array{F64,1})

Calculate the overlap matrix out of projectors. For raw projectors only.
"""
function calc_ovlp(chipsi::Array{C64,4}, weight::Array{F64,1})
    # Extract some key parameters
    nproj, nband, nkpt, nspin = size(chipsi)

    # Create overlap array
    ovlp = zeros(F64, nproj, nproj, nspin)

    # Build overlap array
    for s = 1:nspin
        for k = 1:nkpt
            wght = weight[k] / nkpt
            A = view(chipsi, :, :, k, s)
            ovlp[:, :, s] = ovlp[:, :, s] + real(A * A') * wght
        end
    end

    # Return the desired array
    return ovlp
end

"""
    calc_ovlp(PW::Array{PrWindow,1}, chipsi::Array{Array{C64,4},1}, weight::Array{F64,1})

Calculate the overlap matrix out of projectors. For normalized projectors only.
"""
function calc_ovlp(PW::Array{PrWindow,1}, chipsi::Array{Array{C64,4},1}, weight::Array{F64,1})
    ovlp = Array{F64,3}[]

    for p in eachindex(PW)
        # Extract some key parameters
        ndim, nbnd, nkpt, nspin = size(chipsi[p])
        @assert nbnd === PW[p].nbnd

        # Create overlap array
        M = zeros(F64, ndim, ndim, nspin)

        # Build overlap array
        for s = 1:nspin
            for k = 1:nkpt
                wght = weight[k] / nkpt
                A = view(chipsi[p], :, :, k, s)
                M[:, :, s] = M[:, :, s] + real(A * A') * wght
            end
        end
        push!(ovlp, M)
    end

    # Return the desired array
    return ovlp
end

"""
    calc_dm(chipsi::Array{C64,4}, weight::Array{F64,1}, occupy::Array{F64,3})

Calculate the density matrix out of projectors. For raw projectors only.
"""
function calc_dm(chipsi::Array{C64,4}, weight::Array{F64,1}, occupy::Array{F64,3})
    # Extract some key parameters
    nproj, nband, nkpt, nspin = size(chipsi)

    # Evaluate spin factor
    sf = (nspin === 1 ? 2 : 1)

    # Create density matrix array
    dm = zeros(F64, nproj, nproj, nspin)

    # Build density matrix array
    for s = 1:nspin
        for k = 1:nkpt
            wght = weight[k] / nkpt * sf
            occs = occupy[:, k, s]
            A = view(chipsi, :, :, k, s)
            dm[:, :, s] = dm[:, :, s] + real(A * Diagonal(occs) * A') * wght
        end
    end

    # Return the desired array
    return dm
end

"""
    calc_dm(PW::Array{PrWindow,1}, chipsi::Array{Array{C64,4},1}, weight::Array{F64,1}, occupy::Array{F64,3})

Calculate the density matrix out of projectors. For normalized projectors only.
"""
function calc_dm(PW::Array{PrWindow,1}, chipsi::Array{Array{C64,4},1}, weight::Array{F64,1}, occupy::Array{F64,3})
    dm = Array{F64,3}[]

    for p in eachindex(PW)
        # Extract some key parameters
        ndim, nbnd, nkpt, nspin = size(chipsi[p])
        @assert nbnd === PW[p].nbnd

        # Evaluate spin factor
        sf = (nspin === 1 ? 2 : 1)

        # Create density matrix array
        M = zeros(F64, ndim, ndim, nspin)

        # Build density matrix array
        for s = 1:nspin
            for k = 1:nkpt
                wght = weight[k] / nkpt * sf
                occs = occupy[PW[p].bmin:PW[p].bmax, k, s]
                A = view(chipsi[p], :, :, k, s)
                M[:, :, s] = M[:, :, s] + real(A * Diagonal(occs) * A') * wght
            end
        end

        push!(dm, M)
    end

    # Return the desired array
    return dm
end

"""
    calc_hamk(PW::Array{PrWindow,1}, chipsi::Array{Array{C64,4},1}, weight::Array{F64,1}, enk::Array{F64,3})

Try to build the local hamiltonian. For normalized projectors only.
"""
function calc_hamk(PW::Array{PrWindow,1}, chipsi::Array{Array{C64,4},1}, weight::Array{F64,1}, enk::Array{F64,3})
    hamk = Array{C64,3}[]

    for p in eachindex(PW)
        # Extract some key parameters
        ndim, nbnd, nkpt, nspin = size(chipsi[p])
        @assert nbnd === PW[p].nbnd

        # Create hamiltonian array
        H = zeros(C64, ndim, ndim, nspin)

        # Build hamiltonian array
        for s = 1:nspin
            for k = 1:nkpt
                wght = weight[k] / nkpt
                eigs = enk[PW[p].bmin:PW[p].bmax, k, s]
                A = view(chipsi[p], :, :, k, s)
                H[:, :, s] = H[:, :, s] + (A * Diagonal(eigs) * A') * wght
            end
        end

        push!(hamk, H)
    end

    # Return the desired array
    return hamk
end

"""
    calc_dos()

Try to calculate the density of states.
"""
function calc_dos(PW::Array{PrWindow,1}, chipsi::Array{Array{C64,4},1}, itet::Array{I64,2}, enk::Array{F64,3})
    mesh = collect(-3.0:0.01:3.0)
    #pdos = Array{F64,3}[]

    for p in eachindex(PW)
        # Extract some key parameters
        ndim, nbnd, nkpt, nspin = size(chipsi[p])
        @assert nbnd === PW[p].nbnd

        dos = zeros(F64, length(mesh), ndim, nspin)

        for i in eachindex(mesh)
            wght = tetra_dos(mesh[i], itet, enk[PW[p].bmin:PW[p].bmax, :, :])
            for q = 1:ndim
                for s = 1:nspin
                    for k = 1:nkpt
                        for b = 1:nbnd
                            dos[i, q, s] = dos[i, q, s] + wght[b, k, s] * real( chipsi[p][q, b, k, s] * conj(chipsi[p][q, b, k, s]) )
                        end
                    end
                end
            end
            print(mesh[i], " ")
            foreach(x -> @printf("%12.7f", x), dos[i, :, 1])
            println()
        end
    end
end

#
# Service Functions (Group D)
#

"""
    view_ovlp(ovlp::Array{F64,3})

Output the overlap matrix. A general version.
"""
function view_ovlp(ovlp::Array{F64,3})
    # Extract some key parameters
    _, nproj, nspin = size(ovlp)

    # Output the data
    println("<- Overlap Matrix ->")
    for s = 1:nspin
        println("Spin: $s")
        for p = 1:nproj
            foreach(x -> @printf("%12.7f", x), ovlp[p, :, s])
            println()
        end
    end
end

"""
    view_ovlp(PG::Array{PrGroup,1}, ovlp::Array{Array{F64,3},1})

Output the overlap matrix. For normalized projectors only.
"""
function view_ovlp(PG::Array{PrGroup,1}, ovlp::Array{Array{F64,3},1})
    # Output the data
    println("<- Overlap Matrix ->")
    for p in eachindex(PG)
        println("Site -> $(PG[p].site) L -> $(PG[p].l) Shell -> $(PG[p].shell)")

        # Extract some key parameters
        _, ndim, nspin = size(ovlp[p])

        for s = 1:nspin
            println("Spin: $s")
            for q = 1:ndim
                foreach(x -> @printf("%12.7f", x), ovlp[p][q, 1:ndim, s])
                println()
            end
        end
    end
end

"""
    view_dm(dm::Array{F64,3})

Output the density matrix. A general version.
"""
function view_dm(dm::Array{F64,3})
    # Extract some key parameters
    _, nproj, nspin = size(dm)

    # Output the data
    println("<- Density Matrix ->")
    for s = 1:nspin
        println("Spin: $s")
        for p = 1:nproj
            foreach(x -> @printf("%12.7f", x), dm[p, :, s])
            println()
        end
    end
end

"""
    view_dm(PG::Array{PrGroup,1}, dm::Array{Array{F64,3},1})

Output the density matrix. For normalized projectors only.
"""
function view_dm(PG::Array{PrGroup,1}, dm::Array{Array{F64,3},1})
    # Output the data
    println("<- Density Matrix ->")
    for p in eachindex(PG)
        println("Site -> $(PG[p].site) L -> $(PG[p].l) Shell -> $(PG[p].shell)")

        # Extract some key parameters
        _, ndim, nspin = size(dm[p])

        for s = 1:nspin
            println("Spin: $s")
            for q = 1:ndim
                foreach(x -> @printf("%12.7f", x), dm[p][q, 1:ndim, s])
                println()
            end
        end
    end
end

"""
    view_hamk(PG::Array{PrGroup,1}, hamk::Array{Array{C64,3},1})

Output the local hamiltonian. For normalized projectors only.
"""
function view_hamk(PG::Array{PrGroup,1}, hamk::Array{Array{C64,3},1})
    # Output the data
    println("<- Local Hamiltonian ->")
    for p in eachindex(PG)
        println("Site -> $(PG[p].site) L -> $(PG[p].l) Shell -> $(PG[p].shell)")

        # Extract some key parameters
        _, ndim, nspin = size(hamk[p])

        for s = 1:nspin
            println("Spin: $s")
            println("Re:")
            for q = 1:ndim
                foreach(x -> @printf("%12.7f", x), real(hamk[p][q, 1:ndim, s]))
                println()
            end
            println("Im:")
            for q = 1:ndim
                foreach(x -> @printf("%12.7f", x), imag(hamk[p][q, 1:ndim, s]))
                println()
            end
        end
    end
end

"""
    view_dos()
"""
function view_dos() end
