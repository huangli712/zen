#
# Project : Pansy
# Source  : ZenCore.jl
# Author  : Li Huang (lihuang.dmft@gmail.com)
# Status  : Unstable
#
# Last modified: 2021/07/06
#

"""
    Zen and ZenCore

`Zen` is a modern DFT + DMFT computation framework. It can be used to
study the correlated electronic structures of a wide range of strongly
correlated materials. Now this framework is under heavy development.
**PLEASE USE IT AT YOUR OWN RISK**.

Zen supports the following DFT backends:
* `VASP`

Zen supports the following schemes for defining local orbitals:
* `PLO`
* `WANNIER`

Zen supports the following quantum impurity solvers:
* `CT-HYB`
* `HIA`
* `NORG`

`ZenCore` implements the core library of the Zen DFT + DMFT computation
framework. It connects various components of Zen, and drive them to work
together. It provides an easy-to-use, flexible, efficient, and robust
user interface, including various applications and tools.

For more details about how to obtain, install and use the Zen framework
and the ZenCore library, please visit the following website:
* `http://doc.zen`

Any suggestions, comments, and feedbacks are welcome. Enjoy it!
"""
module ZenCore

#=
### *Using Standard Libraries*
=#

#=
*About TOML.jl* :

The TOML.jl package is included in the standard library of julia since
v1.6. So please upgrade your julia environment if it is outdated. We
need this package to parse the configuration file (which is written in
the TOML format).

*About libm* :

Here we import `libm` explicitly to provide a callable interface for
the `erf()` function. Please see `util.jl/erf()` for more details. We
usually need this to calculate the electronic density of states.
=#

using TOML
using LinearAlgebra
using Distributed
using Dates
using Printf
using Base.Math: libm

#=
### *Includes And Exports* : *global.jl*
=#

#=
*Summary* :

Define some type aliases and string constants for the ZenCore package.

*Members* :

```text
I32, I64    -> Numerical types (Integer).
F32, F64    -> Numerical types (Float).
C32, C64    -> Numerical types (Complex).
R32, R64    -> Numerical types (Union of Integer and Float).
N32, N64    -> Numerical types (Union of Integer, Float, and Complex).
__LIBNAME__ -> Name of this package.
__VERSION__ -> Version of this package.
__RELEASE__ -> Released date of this package.
__AUTHORS__ -> Authors of this package.
authors     -> Print the authors of ZenCore to screen.
```
=#

#
include("global.jl")
#
export I32, I64
export F32, F64
export C32, C64
export R32, R64
export N32, N64
export __LIBNAME__
export __VERSION__
export __RELEASE__
export __AUTHORS__
export authors

#=
### *Includes And Exports* : *util.jl*
=#

#=
*Summary* :

To provide some useful utility macros and functions. They can be used
to colorize the output strings, query the environments, and parse the
input strings, etc.

*Members* :

```text
@cswitch      -> C-style switch.
@time_call    -> Evaluate a function call and print the elapsed time.
@ps1          -> Wrapper for printstyled function.
@ps2          -> Another wrapper for printstyled function.
require       -> Check julia envirnoment.
setup_args    -> Setup ARGS manually.
query_args    -> Query program's arguments.
query_case    -> Query case (job's name).
query_inps    -> Query input files.
query_stop    -> Query case.stop file.
query_home    -> Query home directory of Zen framework.
query_core    -> Query home directory of ZenCore (where is ZenCore.jl).
query_dft     -> Query home directory of DFT engine.
query_dmft    -> Query home directory of DMFT engine.
query_solver  -> Query home directory of quantum impurity solvers.
welcome       -> Print welcome message.
overview      -> Print runtime information of ZenCore.
goodbye       -> Say goodbye.
sorry         -> Say sorry.
prompt        -> Print some messages or logs to the output devices.
line_to_array -> Convert a line to a string array.
line_to_cmplx -> Convert a line to a cmplx number.
erf           -> Gauss error function.
subscript     -> Convert a number to subscript.
```
=#

#
include("util.jl")
#
export @cswitch
export @time_call
export @ps1
export @ps2
export require
export setup_args
export query_args
export query_case
export query_inps
export query_stop
export query_home
export query_core
export query_dft
export query_dmft
export query_solver
export welcome
export overview
export goodbye
export sorry
export prompt
export line_to_array
export line_to_cmplx
export erf
export subscript

#=
### *Includes And Exports* : *tetra.jl*
=#

#=
*Summary* :

Implementation of the analytical tetrahedron method.

*Members* :

```text
TetraWeight  -> Struct for integration weights.
bzint        -> Compute tetrahedron integrated weights.
gauss_weight -> Compute integrated weights using Gaussian broadening.
fermi_weight -> Compute integrated weights using Fermi-Dirac broadening.
tetra_weight -> Compute integrated weights for a given tetrahedron.
tetra_p_ek1  -> Blochl tetrahedron integration algorithm, case 1.
tetra_p_ek12 -> Blochl tetrahedron integration algorithm, case 2.
tetra_p_ek23 -> Blochl tetrahedron integration algorithm, case 3.
tetra_p_ek34 -> Blochl tetrahedron integration algorithm, case 4.
tetra_p_ek4  -> Blochl tetrahedron integration algorithm, case 5.
```
=#

#
include("tetra.jl")
#
export TetraWeight
export bzint
export gauss_weight
export fermi_weight
export tetra_weight
export tetra_p_ek1
export tetra_p_ek12
export tetra_p_ek23
export tetra_p_ek34
export tetra_p_ek4

#=
### *Includes And Exports* : *types.jl*
=#

#=
*Summary* :

Define some dicts and structs, which are used to store the config
parameters or represent some essential data structures.

*Members* :

```text
PCASE    -> Dict for case.
PDFT     -> Dict for DFT engine.
PDMFT    -> Dict for DMFT engine.
PIMP     -> Dict for quantum impurity problems.
PSOLVER  -> Dict for quantum impurity solvers.
Logger   -> Struct for logger.
IterInfo -> Struct for DFT + DMFT iteration information.
Lattice  -> Struct for crystallography information.
Mapping  -> Struct for mapping between impurity problems and projectors.
Impurity -> Struct for quantum impurity problems.
PrTrait  -> Struct for projectors.
PrGroup  -> Struct for groups of projectors.
PrWindow -> Struct for band window.
```
=#

#
include("types.jl")
#
export PCASE
export PDFT
export PDMFT
export PIMP
export PSOLVER
export Logger
export IterInfo
export Lattice
export Mapping
export Impurity
export PrTrait
export PrGroup
export PrWindow

#=
### *Includes And Exports* : *config.jl*
=#

#=
*Summary* :

To extract, parse, verify, and print the configuration parameters.
They are stored in external files (case.toml) or dictionaries.

*Members* :

```text
setup    -> Setup parameters.
inp_toml -> Parse case.toml, return raw configuration information.
rev_dict -> Update dicts for configuration parameters.
chk_dict -> Check dicts for configuration parameters.
exhibit  -> Display parameters for reference.
_v       -> Verify dict's values.
cat_c    -> Print dict (PCASE dict).
cat_d    -> Print dict (PDFT dict).
cat_m    -> Print dict (PDMFT dict).
cat_i    -> Print dict (PIMP dict).
cat_s    -> Print dict (PSOLVER dict).
get_c    -> Extract value from dict (PCASE dict), return raw value.
get_d    -> Extract value from dict (PDFT dict), return raw value.
get_m    -> Extract value from dict (PDMFT dict), return raw value.
get_i    -> Extract value from dict (PIMP dict), return raw value.
get_s    -> Extract value from dict (PSOLVER dict), return raw value.
str_c    -> Extract value from dict (PCASE dict), return string.
str_d    -> Extract value from dict (PDFT dict), return string.
str_m    -> Extract value from dict (PDMFT dict), return string.
str_i    -> Extract value from dict (PIMP dict), return string.
str_s    -> Extract value from dict (PSOLVER dict), return string.
```
=#

#
include("config.jl")
#
export setup
export inp_toml
export rev_dict
export chk_dict
export exhibit
export _v
export cat_c
export cat_d
export cat_m
export cat_i
export cat_s
export get_c
export get_d
export get_m
export get_i
export get_s
export str_c
export str_d
export str_m
export str_i
export str_s

#=
### *Includes And Exports* : *base.jl*
=#

#=
*Summary* :

To provide the core functions to control the DFT engine, DMFT engine,
quantum impurity solvers, Kohn-Sham adaptor, self-energy engine, and
mixer engine. The DFT + DMFT iteration (one-shot mode or charge fully
self-consistent mode) is also implemented in this file. This file also
includes some functions to watch and manipulate the IterInfo struct.

*Members* :

```text
ready       -> Prepare runtime environment for DFT + DMFT calculations.
go          -> Dispatcher for DFT + DMFT calculations.
final       -> Finalize the DFT + DMFT calculations.
cycle1      -> Perform DFT + DMFT calculations (one-shot mode).
cycle2      -> Perform DFT + DMFT calculations (fully self-consistent mode).
cycle3      -> Execute DFT engine only (for testing purpose).
cycle4      -> Execute DMFT engine only (for testing purpose).
cycle5      -> Execute quantum impurity solvers only (for testing purpose).
cycle6      -> Execute Kohn-Sham adaptor only (for testing purpose).
cycle7      -> Execute self-energy engine only (for testing purpose).
cycle8      -> Execute mixer engine only (for testing purpose).
monitor     -> Monitor the DFT + DMFT calculations.
suspend     -> Suspend the DFT engine.
dft_run     -> Driver for DFT engine.
dmft_run    -> Driver for DMFT engine.
solver_run  -> Driver for quantum impurity solvers.
adaptor_run -> Driver for Kohn-Sham adaptor.
sigma_core  -> Driver for self-energy engine.
mixer_core  -> Driver for mixer engine.
build_trees -> Make working directories.
clear_trees -> Remove working directories.
incr_it     -> Increase the counters in the IterInfo struct.
zero_it     -> Reset the counters in the IterInfo struct.
prev_it     -> Return the previous iteration information.
cntr_it     -> Return the counters in the IterInfo struct.
show_it     -> Print the iteration information.
conv_it     -> Check whether the convergence flags are achieved.
```
=#

#
include("base.jl")
#
export ready
export go
export final
export cycle1
export cycle2
export cycle3
export cycle4
export cycle5
export cycle6
export cycle7
export cycle8
export monitor
export suspend
export dft_run
export dmft_run
export solver_run
export adaptor_run
export sigma_core
export mixer_core
export build_trees
export clear_trees
export incr_it
export zero_it
export prev_it
export cntr_it
export show_it
export conv_it

#=
### *Includes And Exports* : *vasp.jl*
=#

#=
*Summary* :

Tools for the vasp software package (adaptor). It provide a lot of
functions to deal with the vasp-related files.

*Members :

```text
vasp_adaptor   -> Adaptor support.
vasp_init      -> Prepare vasp's input files.
vasp_exec      -> Execute vasp program.
vasp_save      -> Backup vasp's output files.
vaspc_incar    -> Generate essential input file (INCAR).
vaspc_kpoints  -> Generate essential input file (KPOINTS).
vaspc_gamma    -> Generate essential input file (GAMMA).
vaspc_lock     -> Create/Delete the vasp.lock file.
vaspq_lock     -> Check the vasp.lock file.
vaspq_files    -> Check essential output files.
vaspio_nband   -> Determine number of bands.
vaspio_valence -> Read number of valence electrons for each sort.
vaspio_procar  -> Read PROCAR file.
vaspio_lattice -> Read lattice information.
vaspio_kmesh   -> Read kmesh.
vaspio_tetra   -> Read tetrahedra.
vaspio_eigen   -> Read eigenvalues.
vaspio_projs   -> Read projectors.
vaspio_fermi   -> Read fermi level.
vaspio_charge  -> Read charge density.
```
=#

#
include("vasp.jl")
#
export vasp_adaptor
export vasp_init
export vasp_exec
export vasp_save
export vaspc_incar
export vaspc_kpoints
export vaspc_gamma
export vaspc_lock
export vaspq_lock
export vaspq_files
export vaspio_nband
export vaspio_valence
export vaspio_procar
export vaspio_lattice
export vaspio_kmesh
export vaspio_tetra
export vaspio_eigen
export vaspio_projs
export vaspio_fermi
export vaspio_charge

#=
### *Includes And Exports* : *plo.jl*
=#

#=
*Summary* :

Tools for the projection on localized orbitals scheme (adaptor).

*Members*:

```text
plo_adaptor -> Adaptor support.
plo_map     -> Create connection between projectors and impurity problems.
plo_fermi   -> Calibrate Kohn-Sham eigenvalues with respect to fermi level.
plo_group   -> Setup groups of projectors.
plo_window  -> Setup band windows of projectors.
plo_rotate  -> Rotate the projectors.
plo_filter  -> Extract the projectors within a given energy window.
plo_orthog  -> Orthogonalize / normalize the projectors.
plo_monitor -> Generate some physical quantities using the projectors.
get_win1    -> Evaluate band window.
get_win2    -> Evaluate energy window.
try_blk1    -> Orthogonalize / normalize the projectors group by group.
try_blk2    -> Orthogonalize / normalize the projectors with each other.
try_diag    -> Orthogonalizes a projector defined by a rectangular matrix.
calc_ovlp   -> Calculate overlap matrix.
calc_dm     -> Calculate density matrix.
calc_hamk   -> Calculate local hamiltonian or full hamiltonian.
calc_dos    -> Calculate density of states.
view_ovlp   -> Show overlap matrix for debug.
view_dm     -> Show density matrix for debug.
view_hamk   -> Show local hamiltonian for debug.
view_dos    -> Show density of states for debug.
```
=#

#
include("plo.jl")
#
export plo_adaptor
export plo_map
export plo_fermi
export plo_group
export plo_window
export plo_rotate
export plo_filter
export plo_orthog
export plo_monitor
export get_win1
export get_win2
export try_blk1
export try_blk2
export try_diag
export calc_ovlp
export calc_dm
export calc_hamk
export calc_dos
export view_ovlp
export view_dm
export view_hamk
export view_dos

#=
### *Includes And Exports* : *ir.jl*
=#

#=
*Summary* :

Tools for the intermediate representation format (adaptor).

*Members* :

```text
ir_adaptor   -> Adaptor support.
ir_save      -> Save the output files by the adaptor.
irio_params  -> Write key parameters extracted from Kohn-Sham data.
irio_maps    -> Write Mapping.
irio_groups  -> Write PrGroup.
irio_windows -> Write PrWindow.
irio_lattice -> Write lattice information.
irio_kmesh   -> Write kmesh.
irio_tetra   -> Write tetrahedra.
irio_eigen   -> Write eigenvalues.
irio_projs   -> Write projectors.
irio_fermi   -> Write fermi level.
irio_charge  -> Write charge density.
```
=#

#
include("ir.jl")
#
export ir_adaptor
export ir_save
export irio_params
export irio_maps
export irio_groups
export irio_windows
export irio_lattice
export irio_kmesh
export irio_tetra
export irio_eigen
export irio_projs
export irio_fermi
export irio_charge

#=
### *Includes And Exports* : *dmft.jl*
=#

#=
*Summary* :

Wrapper for dynamical mean-field theory engine. It also provides some
essential tools to deal with (read and write) the fermi level ``\mu``,
hybridization functions ``\Delta``, local impurity levels ``\epsilon_i``,
and correlation-induced correction for density matrix ``\Gamma``.

*Members* :

```text
dmft_init   -> Prepare input files for the DMFT engine.
dmft_exec   -> Execute the DMFT engine.
dmft_save   -> Backup output files for the DMFT engine.
read_fermi  -> Read dmft1/dmft.fermi or dmft2/dmft.fermi.
read_delta  -> Read dmft1/dmft.delta or impurity.i/dmft.delta.
read_eimpx  -> Read dmft1/dmft.eimpx or impurity.i/dmft.eimpx.
read_gamma  -> Read dmft2/dmft.gamma.
write_delta -> Write dmft1/dmft.delta or impurity.i/dmft.delta.
write_eimpx -> Write dmft1/dmft.eimpx or impurity.i/dmft.eimpx.
write_gamma -> Write dmft2/dmft.gamma.
```
=#

#
include("dmft.jl")
#
export dmft_init
export dmft_exec
export dmft_save
export read_fermi
export read_delta
export read_eimpx
export read_gamma
export write_delta
export write_eimpx
export write_gamma

#=
### *Includes And Exports* : *solver.jl*
=#

#=
*Summary* :

Wrapper for various quantum impurity solvers. Now only the CT-HYB₁,
CT-HYB₂, HIA, and NORG quantum impurity solvers are supported.

*Members* :

```text
s_qmc1_init -> Prepare input files for the CT-HYB₁ impurity solver.
s_qmc1_exec -> Execute the CT-HYB₁ impurity solver.
s_qmc1_save -> Backup output files for the CT-HYB₁ impurity solver.
s_qmc2_init -> Prepare input files for the CT-HYB₂ impurity solver.
s_qmc2_exec -> Execute the CT-HYB₂ impurity solver.
s_qmc2_save -> Backup output files for the CT-HYB₂ impurity solver.
s_hub1_init -> Prepare input files for the HIA impurity solver.
s_hub1_exec -> Execute the HIA impurity solver.
s_hub1_save -> Backup output files for the HIA impurity solver.
s_norg_init -> Prepare input files for the NORG impurity solver.
s_norg_exec -> Execute the NORG impurity solver.
s_norg_save -> Backup output files for the NORG impurity solver.
ctqmc_setup -> Prepare configuration parameters for CT-QMC impurity solver.
ctqmc_atomx -> Prepare configuration parameters for atomic problem solver.
ctqmc_delta -> Prepare hybridization function for CT-QMC impurity solver.
ctqmc_eimpx -> Prepare local impurity levels for CT-QMC impurity solver.
ctqmc_sigma -> Return self-energy function by CT-QMC impurity solver.
ctqmc_nimpx -> Return impurity occupancy by CT-QMC impurity solver.
GetSigma    -> Parse the self-energy functions.
GetNimpx    -> Parse the impurity occupancy.
GetSymmetry -> Analyze orbital degeneracy via local impurity levels.
GetImpurity -> Build Impurity struct according to configuration file.
CatImpurity -> Display Impurity struct that need to be solved.
```
=#

#
include("solver.jl")
#
export s_qmc1_init
export s_qmc1_exec
export s_qmc1_save
export s_qmc2_init
export s_qmc2_exec
export s_qmc2_save
export s_hub1_init
export s_hub1_exec
export s_hub1_save
export s_norg_init
export s_norg_exec
export s_norg_save
export ctqmc_setup
export ctqmc_atomx
export ctqmc_delta
export ctqmc_eimpx
export ctqmc_sigma
export ctqmc_nimpx
export GetSigma
export GetNimpx
export GetSymmetry
export GetImpurity
export CatImpurity

#=
### *Includes And Exports* : *sigma.jl*
=#

#=
*Summary* :

Tools for treating the self-energy functions ``\Sigma``, double counting
terms ``\Sigma_{\text{dc}}``. Note that the function `sigma_split()` is
designed for the hybridization functions ``\Delta`` and local impurity
levels ``\epsilon_i``, instead of the self-energy functions.

*Members* :

```text
sigma_reset  -> Create initial self-energy functions.
sigma_dcount -> Calculate double counting terms.
sigma_split  -> Split the hybridization functions and local impurity levels.
sigma_gather -> Gather and combine the self-energy functions.
cal_dc_fll   -> Fully localized limit scheme for double counting term.
cal_dc_amf   -> Around mean-field scheme for double counting term.
cal_dc_held  -> K. Held's scheme for double counting term.
cal_dc_exact -> Exact double counting scheme.
read_sigma   -> Read dmft1/sigma.bare file.
read_sigdc   -> Read dmft1/sigma.dc file.
write_sigma  -> Write dmft1/sigma.bare file.
write_sigdc  -> Write dmft1/sigma.dc file.
```
=#

#
include("sigma.jl")
#
export sigma_reset
export sigma_dcount
export sigma_split
export sigma_gather
export cal_dc_fll
export cal_dc_amf
export cal_dc_held
export cal_dc_exact
export read_sigma
export read_sigdc
export write_sigma
export write_sigdc

#=
### *Includes And Exports* : *mixer.jl*
=#

#=
*Summary* :

Tools for mixing the self-energy functions ``\Sigma``, hybridization
functions ``\Delta``, and local impurity levels ``\epsilon_i``. They
adopted the linear mixing algorithm. We also implement the so-called
Kerker algorithm to mix the correlation-induced correction for density
matrix ``\Gamma``.

*Members* :

```text
mixer_sigma -> Mix self-energy functions.
mixer_delta -> Mix hybridization functions.
mixer_eimpx -> Mix local impurity levels.
mixer_gamma -> Mix correction of density matrix Γ.
amix        -> Return the mixing parameter.
distance    -> Calculate the difference /distance between two arrays.
```
=#

#
include("mixer.jl")
#
export mixer_sigma
export mixer_delta
export mixer_eimpx
export mixer_gamma
export amix
export distance

#=
### *PreCompile*
=#

"""
    __init__()

This function would be executed immediately after the module is loaded
at runtime for the first time. Here, we would like to precompile the
whole `ZenCore` package to reduce the runtime latency and speed up the
successive calculations.
"""
function __init__()
    prompt("Loading...")

    # Get an array of the names exported by the `ZenCore` module
    nl = names(ZenCore)

    # Go through each name
    cf = 0 # Counter
    for i in eachindex(nl)
        # Please pay attention to that nl[i] is a Symbol, we need to
        # convert it into string and function, respectively.
        str = string(nl[i])
        fun = eval(nl[i])

        # For methods only (macros must be excluded)
        if fun isa Function && !startswith(str, "@")
            # Increase the counter
            cf = cf + 1

            # Extract the signature of the function
            # Actually, `types` is a Core.SimpleVector.
            types = typeof(fun).name.mt.defs.sig.types

            # Convert `types` from SimpleVector into Tuple
            # If length(types) is 1, the method is without arguments.
            T = ()
            if length(types) > 1
                T = tuple(types[2:end]...)
            end

            # Precompile them one by one
            # println(i, " -> ", str, " -> ", length(types), " -> ", T)
            precompile(fun, T)
            @printf("Function %15s (#%3i) is compiled.\r", str, cf)
        end
    end

    prompt("Well, ZenCore is compiled and loaded ($cf functions).")
    prompt("We are ready to go!")
    println()
end

end # END OF MODULE
