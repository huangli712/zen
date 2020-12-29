#!/usr/bin/env julia

include("Zen.jl")
using .Zen

#welcome()

#it = IterInfo(1)
#@show it
#latt = vaspio_lattice(pwd())
#@show latt
#PG = PrGroup(2, 0)
#@show PG
#PGT = PrGroupT(PG)
#@show PGT

# test vaspio_kmesh() and irio_kmesh()
#--------------------------------------
#kmesh, weight = vaspio_kmesh(joinpath(pwd(), "dft"))
#irio_kmesh(pwd(), kmesh, weight)

# test vaspio_tetra() and irio_tetra()
#--------------------------------------
#volt, itet = vaspio_tetra(joinpath(pwd(), "dft"))
#irio_tetra(pwd(), volt, itet)

# test vaspio_eigen() and irio_eigen()
#--------------------------------------
#enk, occupy = vaspio_eigen(joinpath(pwd(), "dft"))
#irio_eigen(pwd(), enk, occupy)

# test vaspio_projs() and irio_projs()
#--------------------------------------
#PT, PG, chipsi2 = vaspio_projs(joinpath(pwd(), "dft"))
#irio_projs(pwd(), chipsi2)
#for i in eachindex(PT)
#    @show i, PT[i]
#end
#
#for i in eachindex(PG)
#    @show i, PG[i]
#end

# test vaspio_fermi() and irio_fermi()
#--------------------------------------
#fermi = vaspio_fermi(joinpath(pwd(), "dft"))
#irio_fermi(pwd(), fermi)

# test vaspio_lattice()
#--------------------------------------
#latt = vaspio_lattice(pwd())
#cfg = parse_toml(query_args(), true)
#renew_config(cfg)
#plo_group(PG)
#for i in eachindex(PG)
#    @show i, PG[i]
#end
#irio_lattice(pwd(), latt)

#orb_labels = ("s",
#              "py", "pz", "px",
#              "dxy", "dyz", "dz2", "dxz", "dx2-y2",
#              "fz3", "fxz2", "fyz2", "fz(x2-y2)", "fxyz", "fx(x2-3y2)", "fy(3x2-y2)")
#
#for i in eachindex(orb_labels)
#    PrTrait(2, orb_labels[i])
#end

#PT, PG, chipsi = vaspio_projs(joinpath(pwd(), "dft"))
#kmesh, weight = vaspio_kmesh(joinpath(pwd(), "dft"))
#enk, occupy = vaspio_eigen(joinpath(pwd(), "dft"))
#fermi = vaspio_fermi(joinpath(pwd(), "dft"))
#cfg = parse_toml(query_args(), true)
#renew_config(cfg)
#plo_group(PG)
#PGT, chipsi_r = plo_rotate(PG, chipsi)
#enk = enk .- fermi
##bmin, bmax, ib_window, chipsi_w = plo_window(enk, 2.0, -1.4, chipsi_r)
#bmin, bmax, ib_window, chipsi_w = plo_window(enk, 5.0, -3.4, chipsi_r)
#plo_orthog(ib_window, PGT, chipsi_w)
#plo_ovlp(PGT, chipsi_w, weight)
#plo_dm(bmin, bmax, PGT, chipsi_w, weight, occupy)
#exit(-1)

#ovlp = plo_ovlp(chipsi, weight)
#dm = plo_dm(chipsi, weight, occupy)
#view_ovlp(ovlp)
#view_dm(dm)