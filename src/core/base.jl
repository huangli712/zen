#
# Project : Pansy
# Source  : base.jl
# Author  : Li Huang (lihuang.dmft@gmail.com)
# Status  : Unstable
#
# Last modified: 2021/07/08
#

#=
### *Driver Functions* : *Layer 1*
=#

"""
    ready()

Examine whether all the conditions, including input files and working
directories, for DFT + DMFT calculations are ready.

See also: [`go`](@ref).
"""
function ready()
    # R1: Check the input files
    query_inps(get_d("engine"))

    # R2: Prepare the working directories
    build_trees()
end

"""
    go()

Dispatcher for DFT + DMFT calculations. Note that it can not call the
`cycle3()`-`cycle8()` functions. These functions are designed only for
testing purpose.

See also: [`ready`](@ref).
"""
function go()
    # Get calculation mode
    mode = get_m("mode")

    # Choose suitable computational driver
    @cswitch mode begin
        # One-shot DFT + DMFT calculations
        @case 1
            cycle1()
            break

        # Fully self-consistent DFT + DMFT calculations
        @case 2
            cycle2()
            break

        # To be implemented
        @default
            sorry()
            break
    end
end

"""
    final()

Finalize the DFT + DMFT calculations.

See also: [`go`](@ref).
"""
function final()
    prompt("It is time to sleep. See you later.")
end

#=
### *Driver Functions* : *Layer 2*
=#

#=
*Some Explanations for the DFT + DMFT Algorithm*

*Remarks 1* :

We would like to perform two successive DFT runs if `get_d("loptim")` is
true. The purpose of the first DFT run is to evaluate the fermi level.
Then an energy window is determined. We will use this window to generate
optimal projectors in the second DFT run.

On the other hand, if `get_d("loptim")` is false, only the first DFT run
is enough.

*Remarks 2* :

We want better *optimal projectors*.

In the previous DFT run, `initial` fermi level = 0 -> `wrong` energy
window -> `wrong` optimial projectors. But at this point, the fermi
level is updated, so we have to generate the optimal projectors
again within this new window by doing addition DFT calculation.

*Remarks 3* :

The key Kohn-Sham data inclue lattice structures, 𝑘-mesh and its weights,
tetrahedra data, eigenvalues, raw projectors, and fermi level, etc. At
first, the adaptor will read in these data from the output files of DFT
engine. And then it will process the raw projectors (such as parsing,
labeling, grouping, filtering, and rotatation). Finally, the adaptor will
write down the processed data to some specified files using the `IR`
format.

*Remarks 4* :

Once everything is ready, we are going to solve the DMFT self-consistent
equation iterately.
=#

"""
    cycle1()

Perform one-shot DFT + DMFT calculations. In other words, the charge
density won't be fed back to the DFT engine. The self-consistency is
only achieved at the DMFT level.

See also: [`cycle2`](@ref), [`go`](@ref).
"""
function cycle1()
    # C-2: Create IterInfo struct
    it = IterInfo()
    it.sc = 1 # One-shot mode

    # C-1: Create Logger struct
    lr = Logger(query_case())

    # C00: Initialize the quantum impurity problems
    ai = GetImpurity()

#
# Initialization (C01-C04)
#
    prompt("Initialization")

    # C01: Perform DFT calculation (for the first time)
    @time_call dft_run(it, lr)

    # C02: Perform DFT calculation (for the second time)
    get_d("loptim") && @time_call dft_run(it, lr)

    # C03: To bridge the gap between DFT engine and DMFT engine by adaptor
    adaptor_run(it, lr, ai)

    # C04: Prepare default self-energy functions
    @time_call sigma_core(it, lr, ai, "reset")

#
# DFT + DMFT Iterations (C05-C12)
#
    prompt("Iterations")
    show_it(it, lr)

    for iter = 1:it.M₃
        # Print the log
        prompt("Cycle $iter")
        prompt(lr.log, "")
        prompt(lr.log, "< dft_dmft_cycle >")

        # Update IterInfo struct
        incr_it(it)

        # C05: Tackle with the double counting term
        @time_call sigma_core(it, lr, ai, "dcount")

        # C06: Perform DMFT calculation with `task` = 1
        @time_call dmft_run(it, lr, 1)

        # C07: Mix the hybridization functions
        @time_call mixer_core(it, lr, ai, "delta")

        # C08: Mix the local impurity levels
        @time_call mixer_core(it, lr, ai, "eimpx")

        # C09: Split and distribute the hybridization functions
        @time_call sigma_core(it, lr, ai, "split")

        # C10: Solve the quantum impurity problems
        @time_call solver_run(it, lr, ai)

        # C11: Gather and combine the impurity self-functions
        @time_call sigma_core(it, lr, ai, "gather")

        # C12: Mix the impurity self-energy functions
        @time_call mixer_core(it, lr, ai, "sigma")

        # Print the cycle info
        show_it(it, lr)

        # If the convergence has been achieved, then break the cycle.
        conv_it(it) && break
    end

    # C98: Close Logger.log
    if isopen(lr.log)
        flush(lr.log)
        close(lr.log)
    end

    # C99: Close Logger.cycle
    if isopen(lr.cycle)
        flush(lr.cycle)
        close(lr.cycle)
    end
end

"""
    cycle2()

Perform fully self-consistent DFT + DMFT calculations. The self-consistency
is achieved at both DFT and DMFT levels. This function doesn't work so far.

See also: [`cycle1`](@ref), [`go`](@ref).
"""
function cycle2()
    # C-2: Create IterInfo struct
    it = IterInfo()
    it.sc = 1 # Still one-shot mode

    # C-1: Create Logger struct
    lr = Logger(query_case())

    # C00: Initialize the quantum impurity problems
    ai = GetImpurity()

#
# Initialization (C01-C04)
#
    prompt("Initialization")

    # C01: Perform DFT calculation (for the first time)
    @time_call dft_run(it, lr)

    # C02: Perform DFT calculation (for the second time)
    get_d("loptim") && @time_call dft_run(it, lr)

    # C03: To bridge the gap between DFT engine and DMFT engine by adaptor
    adaptor_run(it, lr, ai)

    # C04: Prepare default self-energy functions
    @time_call sigma_core(it, lr, ai, "reset")

#
# DFT + DMFT Iterations (C05-C12)
#
    prompt("Iterations")
    show_it(it, lr)

    # C05: Start the self-consistent engine
    it.sc = 2; dft_run(it, lr)

    # Outer: DFT + DMFT LOOP
    for iter = 1:it.M₃

        # Wait additional two seconds
        suspend(2)

        # Print the log
        prompt("Cycle $iter")
        prompt(lr.log, "")
        prompt(lr.log, "< dft_dmft_cycle >")

        # Update IterInfo struct, fix it.I₃
        incr_it(it, 3, iter)

        # C06: Apply the adaptor to extract new Kohn-Sham dataset
        adaptor_run(it, lr, ai)

        # Inner: DMFT LOOP
        for iter1 = 1:it.M₁
            # Update IterInfo struct, fix it.I₁
            incr_it(it, 1, iter1)

            # C07: Tackle with the double counting term
            @time_call sigma_core(it, lr, ai, "dcount")

            # C08: Perform DMFT calculation with `task` = 1
            @time_call dmft_run(it, lr, 1)

            # C09: Mix the hybridization functions
            @time_call mixer_core(it, lr, ai, "delta")

            # C10: Mix the local impurity levels
            @time_call mixer_core(it, lr, ai, "eimpx")

            # C11: Split and distribute the hybridization functions
            @time_call sigma_core(it, lr, ai, "split")

            # C12: Solve the quantum impurity problems
            @time_call solver_run(it, lr, ai)

            # C13: Gather and combine the impurity self-functions
            @time_call sigma_core(it, lr, ai, "gather")

            # C14: Mix the impurity self-energy functions
            @time_call mixer_core(it, lr, ai, "sigma")

            # Print the cycle info
            show_it(it, lr)

            # If the convergence has been achieved, then break the cycle.
            conv_it(it) && break
        end

        # Reset the counter in IterInfo: I₁, I₂
        zero_it(it)

        # Inner: DFT LOOP
        for iter2 = 1:it.M₂
            # Update IterInfo struct, fix it.I₂
            incr_it(it, 2, iter2)

            # C15: Perform DMFT calculation with `task` = 2
            dmft_run(it, lr, 2) # Generate correction for density matrix

            # C10: Mix the correction for density matrix
            @time_call mixer_core(it, lr, ai, "gamma")

            # C17: Reactivate the DFT engine
            dft_run(lr)

            # Print the cycle info
            show_it(it, lr)

            # If the convergence has been achieved, then break the cycle.
            conv_it(it) && break
        end

        # Reset the counter in IterInfo: I₁, I₂
        zero_it(it)

        # C18:

    end
end

"""
    cycle3()

Perform DFT calculations only. If there are something wrong, then you
have chance to adjust the DFT input files manually (for example, you
can modify `vaspc_incar()/vasp.jl` by yourself).

See also: [`cycle1`](@ref), [`cycle2`](@ref).
"""
function cycle3()
    # C-2: Create IterInfo struct
    it = IterInfo()

    # C-1: Create Logger struct
    lr = Logger(query_case())

    # C01: Perform DFT calculation (for the first time)
    @time_call dft_run(it, lr)

    # C02: Perform DFT calculation (for the second time)
    get_d("loptim") && @time_call dft_run(it, lr)

    # C98: Close Logger.log
    if isopen(lr.log)
        flush(lr.log)
        close(lr.log)
    end

    # C99: Close Logger.cycle
    if isopen(lr.cycle)
        flush(lr.cycle)
        close(lr.cycle)
    end
end

"""
    cycle4(task::I64)

Perform DMFT calculations only. The users can execute it in the REPL mode
to see whether the DMFT engine works properly.

See also: [`cycle1`](@ref), [`cycle2`](@ref).
"""
function cycle4(task::I64)
    # C-2: Create IterInfo struct
    it = IterInfo()

    # C-1: Create Logger struct
    lr = Logger(query_case())

    # C01: Execuate the DMFT engine
    @time_call dmft_run(it, lr, task)

    # C98: Close Logger.log
    if isopen(lr.log)
        flush(lr.log)
        close(lr.log)
    end

    # C99: Close Logger.cycle
    if isopen(lr.cycle)
        flush(lr.cycle)
        close(lr.cycle)
    end
end

"""
    cycle5()

Perform calculations using quantum impurity solvers only. The users can
execute it in the REPL mode to see whether the quantum impurity solvers
work properly.

See also: [`cycle1`](@ref), [`cycle2`](@ref).
"""
function cycle5()
    # C-2: Create IterInfo struct
    it = IterInfo()

    # C-1: Create Logger struct
    lr = Logger(query_case())

    # C00: Initialize the quantum impurity problems
    ai = GetImpurity()

    # C01: Execuate the quantum impurity solvers
    @time_call solver_run(it, lr, ai)

    # C98: Close Logger.log
    if isopen(lr.log)
        flush(lr.log)
        close(lr.log)
    end

    # C99: Close Logger.cycle
    if isopen(lr.cycle)
        flush(lr.cycle)
        close(lr.cycle)
    end
end

"""
    cycle6()

Perform calculations using Kohn-Sham adaptor only. The users can execute
it in the REPL mode to see whether the Kohn-Sham adaptor works properly.

See also: [`cycle1`](@ref), [`cycle2`](@ref).
"""
function cycle6()
    # C-2: Create IterInfo struct
    it = IterInfo()

    # C-1: Create Logger struct
    lr = Logger(query_case())

    # C00: Initialize the quantum impurity problems
    ai = GetImpurity()

    # C01: Execute the Kohn-Sham adaptor
    adaptor_run(it, lr, ai)

    # C98: Close Logger.log
    if isopen(lr.log)
        flush(lr.log)
        close(lr.log)
    end

    # C99: Close Logger.cycle
    if isopen(lr.cycle)
        flush(lr.cycle)
        close(lr.cycle)
    end
end

"""
    cycle7(task::String = "reset")

Perform calculations using self-energy engine only. The users can execute
it in the REPL mode to see whether the self-energy engine works properly.

See also: [`cycle1`](@ref), [`cycle2`](@ref).
"""
function cycle7(task::String = "reset")
    # C-2: Create IterInfo struct
    it = IterInfo()

    # C-1: Create Logger struct
    lr = Logger(query_case())

    # C00: Initialize the quantum impurity problems
    ai = GetImpurity()

    # C01: Execute the Kohn-Sham adaptor
    @time_call sigma_core(it, lr, ai, task)

    # C98: Close Logger.log
    if isopen(lr.log)
        flush(lr.log)
        close(lr.log)
    end

    # C99: Close Logger.cycle
    if isopen(lr.cycle)
        flush(lr.cycle)
        close(lr.cycle)
    end
end

"""
    cycle8(task::String = "sigma")

Perform calculations using mixer engine only. The users can execute
it in the REPL mode to see whether the mixer engine works properly.

In order to run this function correctly, sometimes users should modify
the predefined parameters in step `C01`.

See also: [`cycle1`](@ref), [`cycle2`](@ref).
"""
function cycle8(task::String = "sigma")
    # C-2: Create IterInfo struct
    it = IterInfo()

    # C-1: Create Logger struct
    lr = Logger(query_case())

    # C00: Initialize the quantum impurity problems
    ai = GetImpurity()

    # C01: Further setup the IterInfo struct
    #
    # Please modify the I₃ and I₁ parameters to fit your requirements
    it.I₃ = 1
    it.I₁ = 10

    # C02: Execute the Kohn-Sham adaptor
    @time_call mixer_core(it, lr, ai, task)

    # C98: Close Logger.log
    if isopen(lr.log)
        flush(lr.log)
        close(lr.log)
    end

    # C99: Close Logger.cycle
    if isopen(lr.cycle)
        flush(lr.cycle)
        close(lr.cycle)
    end
end

#=
### *Service Functions* : *Layer 1*
=#

#=
*Remarks* :

In order to terminate the `Zen` code, the following two conditions
should be fulfilled at the same time.

* The argument `force_exit` is true.

* The `case.stop` file exists (from `query_stop()` function).

We usually use this functon to stop the whole DFT + DMFT iterations.
=#

"""
    monitor(force_exit::Bool = false)

Determine whether we need to terminate the `Zen` code.

See also: [`query_stop`](@ref).
"""
function monitor(force_exit::Bool = false)
    if force_exit && query_stop()
        exit(-1)
    end
end

"""
    suspend(second::I64)

Suspend the current process to wait the DFT engine. This function is
useful for charge fully self-consistent DFT + DMFT calculations.

Now this function only supports the vasp code. We have to improve it
to support more DFT engines.

See also: [`dft_run`](@ref).
"""
function suspend(second::I64)
    # Check second
    if second ≤ 0
        second = 5
    end

    # Sleep at first
    sleep(second)

    # Enter an infinite loop until some conditions are fulfilled.
    while true
        # Sleep
        sleep(second)
        #
        # Print some hints
        println("Pending for DFT engine")
        #
        # Check the stop condifion.
        # Here, we check the vasp.lock file. If it is absent, then we
        # break this loop
        !vaspq_lock() && break
    end
end

#=
### *Service Functions* : *Layer 2*
=#

"""
    dft_run(it::IterInfo, lr::Logger)

Simple driver for DFT engine. It performs three tasks: (1) Examine
the runtime environment for the DFT engine. (2) Launch the DFT engine.
(3) Backup the output files by DFT engine for next iterations.

Now only the vasp engine is supported. If you want to support the other
DFT engine, this function must be adapted.

See also: [`adaptor_run`](@ref), [`dmft_run`](@ref), [`solver_run`](@ref).
"""
function dft_run(it::IterInfo, lr::Logger)
    # Determine the chosen engine
    engine = get_d("engine")

    # Print the log
    prompt("DFT", cntr_it(it))
    prompt(lr.log, engine)

    # Enter dft directory
    cd("dft")

    # Activate the chosen DFT engine
    @cswitch engine begin
        # For vasp
        @case "vasp"
            vasp_init(it)
            vasp_exec(it)
            vasp_save(it)
            break

        @default
            sorry()
            break
    end

    # Enter the parent directory
    cd("..")

    # Monitor the status
    monitor(true)
end

"""
    dft_run(lr::Logger)

Read in the correction for density matrix, and then feed it back to the
DFT engine to continue the DFT + DMFT calculations.

Now this function only supports the vasp code. We have to improve it
to support more DFT engines.

See also: [`suspend`](@ref).
"""
function dft_run(lr::Logger)
    # Determine the chosen engine
    engine = get_d("engine")

    # Print the log
    prompt("DFT", cntr_it(it))
    prompt(lr.log, engine)

    # Read in the correction for density matrix
    _, kwin, gamma = read_gamma()

    # Enter dft directory
    cd("dft")

    # Activate the chosen DFT engine
    @cswitch engine begin
        # For vasp
        @case "vasp"
            # Write the GAMMA file for vasp
            vaspc_gamma(kwin, gamma)
            #
            # Create vasp.lock file to wake up the vasp
            vaspc_lock("create")
            #
            break

        @default
            sorry()
            break
    end

    # Enter the parent directory
    cd("..")

    # Monitor the status
    monitor(true)
end

"""
    dmft_run(it::IterInfo, lr::Logger, task::I64)

Simple driver for DMFT engine. It performs three tasks: (1) Examine
the runtime environment for the DMFT engine. (2) Launch the DMFT engine.
(3) Backup the output files by DMFT engine for next iterations.

The argument `task` is used to specify running mode of the DMFT code.

See also: [`adaptor_run`](@ref), [`dft_run`](@ref), [`solver_run`](@ref).
"""
function dmft_run(it::IterInfo, lr::Logger, task::I64)
    # Examine the argument `task`
    @assert task === 1 || task === 2

    # Print the log
    prompt("DMFT", cntr_it(it))
    prompt(lr.log, "dmft$task")

    # Enter dmft1 or dmft2 directory
    cd("dmft$task")

    # Activate the chosen DMFT engine
    @cswitch task begin
        # Solve the DMFT self-consistent equation
        @case 1
            dmft_init(it, 1)
            dmft_exec(it, 1)
            dmft_save(it, 1)
            break

        # Generate DMFT correction for DFT charge density
        @case 2
            dmft_init(it, 2)
            dmft_exec(it, 2)
            dmft_save(it, 2)
            break
    end

    # Enter the parent directory
    cd("..")

    # Monitor the status
    monitor(true)
end

"""
    solver_run(it::IterInfo, lr::Logger, ai::Array{Impurity,1}, force::Bool = false)

Simple driver for quantum impurity solvers. It performs three tasks: (1)
Examine the runtime environment for quantum impurity solver. (2) Launch
the quantum impurity solver. (3) Backup output files by quantum impurity
solver for next iterations.

If `force = true`, then we will try to solve all of the quantum impurity
problems explicitly, irrespective of their symmetries.

Now only the `ct_hyb1`, `ct_hyb2`, `hub1`, and `norg` quantum impurity
solvers are supported. If you want to support the other quantum impurity
solvers, this function must be adapted.

See also: [`adaptor_run`](@ref), [`dft_run`](@ref), [`dmft_run`](@ref).
"""
function solver_run(it::IterInfo, lr::Logger, ai::Array{Impurity,1}, force::Bool = false)
    # Sanity check
    @assert length(ai) == get_i("nsite")

    # Analyze the symmetry of quantum impurity problems
    println(blue("Analyze the quantum impurity problems..."))
    #
    # Print number of impurities
    println("  > Number of quantum impurity problems: ", length(ai))
    #
    # Determine the equivalence of quantum impurity problems
    equiv = abs.(get_i("equiv"))
    println("  > Equivalence of quantum impurity problems (abs): ", equiv)
    unique!(equiv)
    println("  > Equivalence of quantum impurity problems (uniq): ", equiv)
    #
    # Figure out which quantum impurity problem should be solved
    to_be_solved = fill(false, length(ai))
    for i in eachindex(equiv)
        ind = findfirst(x -> x.equiv == equiv[i], ai)
        isa(ind, Nothing) && continue
        to_be_solved[ind] = true
    end
    println("  > Quantum impurity problems (keep): ", findall(to_be_solved))
    println("  > Quantum impurity problems (skip): ", findall(.!to_be_solved))
    println(green("Now we are ready to solve them..."))

    # Loop over each impurity site
    for i = 1:get_i("nsite")
        # Extract and show the Impurity strcut
        imp = ai[i]
        CatImpurity(imp)

        # The present quantum impurity problem need to be solved
        if to_be_solved[i] || force
            # Print the header
            println(green("It is interesting. Let us play with it."))

            # Determine the chosen solver
            engine = get_s("engine")

            # Print the log
            prompt("Solvers", cntr_it(it))
            prompt(lr.log, engine)

            # Enter impurity.i directory
            cd("impurity.$i")

            # Activate the chosen quantum impurity solver
            @cswitch engine begin
                @case "ct_hyb1"
                    s_qmc1_init(it, imp)
                    s_qmc1_exec(it)
                    s_qmc1_save(it, imp)
                    break

                @case "ct_hyb2"
                    s_qmc2_init(it)
                    s_qmc2_exec(it)
                    s_qmc2_save(it)
                    break

                @case "hub1"
                    s_hub1_init(it)
                    s_hub1_exec(it)
                    s_hub1_save(it)
                    break

                @case "norg"
                    s_norg_init(it)
                    s_norg_exec(it)
                    s_norg_save(it)
                    break

                @default
                    sorry()
                    break
            end

            # Enter the parent directory
            cd("..")

        else
            # Print the header
            println(red("Mmm, it is not my job..."))

            # Well, the current quantum impurity problem is not solved.
            # We have to find out its sister which has been solved before.
            found = -1
            for j = 1:i
                # Impurity 𝑖 and Impurity 𝑗 are related by some kinds of
                # symmetry. Impurity 𝑗 has been solved before. So we can
                # copy its solution to Impurity 𝑖.
                if abs(imp.equiv) == abs(ai[j].equiv) && to_be_solved[j]
                    found = j
                end
            end
            # Sanity check
            @assert found > 0
            println(green("Maybe we can learn sth. from Impurity $found"))

            # Determine the chosen solver
            engine = get_s("engine")

            # Enter impurity.i directory
            cd("impurity.$i")

            # Next, we would like to copy solution from Impurity `found`
            # to the current Impurity 𝑖.
            @cswitch engine begin
                @case "ct_hyb1"
                    s_qmc1_save(it, ai[found], imp)
                    break

                @case "ct_hyb2"
                    s_qmc2_save(it, ai[found], imp)
                    break

                @case "hub1"
                    s_hub1_save(it, ai[found], imp)
                    break

                @case "norg"
                    s_norg_save(it, ai[found], imp)
                    break

                @default
                    sorry()
                    break
            end

            # Enter the parent directory
            cd("..")

        end
    end # END OF I LOOP

    # Monitor the status
    monitor(true)
end

"""
    adaptor_run(it::IterInfo, lr::Logger, ai::Array{Impurity,1})

Simple driver for the adaptor. It performs three tasks: (1) Initialize
the adaptor, to check whether the essential files exist. (2) Parse the
Kohn-Sham data output by the DFT engine, try to preprocess them, and
then transform them into IR format. (3) Backup the files by adaptor.

For the first task, only the vasp adaptor is supported. While for the
second task, only the PLO adaptor is supported. If you want to support
more adaptors, please adapt this function.

See also: [`dft_run`](@ref), [`dmft_run`](@ref), [`solver_run`](@ref).
"""
function adaptor_run(it::IterInfo, lr::Logger, ai::Array{Impurity,1})
    # Enter dft directory
    cd("dft")

    #
    # A0: Create a dict named DFTData
    #
    # This dictionary is for storing the Kohn-Sham band structure and
    # related data. The key-value pairs would be inserted into this
    # dict dynamically.
    #
    DFTData = Dict{Symbol,Any}()

    #
    # A1: Parse the original Kohn-Sham data
    #
    # Choose suitable driver function according to DFT engine. The
    # Kohn-Sham data will be stored in the DFTData dict.
    #
    engine = get_d("engine")
    prompt("Adaptor", cntr_it(it))
    prompt(lr.log, "adaptor::$engine")
    @cswitch engine begin
        # For vasp
        @case "vasp"
            vaspq_files()
            @time_call vasp_adaptor(DFTData)
            break

        @default
            sorry()
            break
    end

    #
    # A2: Process the original Kohn-Sham data
    #
    # Well, now we have the Kohn-Sham data. But they can not be used
    # directly. We have to check and process them carefully. Please
    # pay attention to that the DFTData dict will be modified in
    # the `plo_adaptor()` function.
    #
    # The plo_adaptor() function also has the ability to calculate
    # some selected physical quantities (such as overlap matrix and
    # density of states) to check the correctness of the Kohn-Sham
    # data. This feature will be activated automatically if you are
    # using the `src/tools/test.jl` tool to examine the DFT data.
    #
    projtype = get_d("projtype")
    prompt("Adaptor", cntr_it(it))
    prompt(lr.log, "adaptor::$projtype")
    @cswitch projtype begin
        # For projected local orbital scheme
        @case "plo"
            @time_call plo_adaptor(DFTData, ai)
            break

        # For maximally localized wannier function scheme
        @case "wannier"
            sorry()
            break

        @default
            sorry()
            break
    end

    #
    # A3: Output the processed Kohn-Sham data
    #
    # Ok, now the Kohn-Sham data are ready. We would like to write them
    # to some specified files with the IR format. Then these files will
    # be saved immediately.
    #
    prompt("Adaptor", cntr_it(it))
    prompt(lr.log, "adaptor::ir")
    @time_call ir_adaptor(DFTData)
    ir_save(it)

    #
    # A4: Clear the DFTData dict
    #
    empty!(DFTData)
    @assert isempty(DFTData)

    # Enter the parent directory
    cd("..")

    # Monitor the status
    monitor(true)
end

"""
    sigma_core(it::IterInfo, lr::Logger, ai::Array{Impurity,1}, task::String = "reset")

Simple driver for functions for processing the self-energy functions
and hybridization functions.

Now it supports four tasks: `reset`, `dcount`, `split`, `gather`. It
won't change the current directory.

See also: [`mixer_core`](@ref).
"""
function sigma_core(it::IterInfo, lr::Logger, ai::Array{Impurity,1}, task::String = "reset")
    # Check the given task
    @assert task in ("reset", "dcount", "split", "gather")

    # Print the log
    prompt("Sigma", cntr_it(it))
    prompt(lr.log, "sigma::$task")

    # Launch suitable subroutine
    @cswitch task begin
        # Generate default self-energy functions and store them
        @case "reset"
            sigma_reset(ai)
            break

        # Calculate the double counting terms and store them
        @case "dcount"
            sigma_dcount(it, ai)
            break

        # Split the hybridization functions and store them
        @case "split"
            sigma_split(ai)
            break

        # Collect impurity self-energy functions and combine them
        @case "gather"
            sigma_gather(it, ai)
            break

        @default
            sorry()
            break
    end

    # Monitor the status
    monitor(true)
end

"""
    mixer_core(it::IterInfo, lr::Logger, ai::Array{Impurity,1}, task::String = "sigma")

Simple driver for the mixer. It will try to mix the self-energy functions
or hybridization functions and generate a new one.

Now it supports four tasks: `sigma`, `delta`, `eimpx`, `gamma`. It
won't change the current directory.

See also: [`sigma_core`](@ref).
"""
function mixer_core(it::IterInfo, lr::Logger, ai::Array{Impurity,1}, task::String = "sigma")
    # Check the given task
    @assert task in ("sigma", "delta", "eimpx", "gamma")

    # Print the log
    prompt("Mixer", cntr_it(it))
    prompt(lr.log, "mixer::$task")

    # Check iteration number to see whether we have enough data to be mixed
    if it.sc == 1
        if it.I₁ ≤ 1
            return
        end
    else
        if task in ("sigma", "delta", "eimpx")
            if it.I₃ == 1 && it.I₁ == 1
                return
            end
        else
            @assert task == "gamma"
            if it.I₃ == 1 && it.I₂ == 1
                return
            end
        end
    end

    # Launch suitable subroutine
    @cswitch task begin
        # Try to mix the self-energy functions
        @case "sigma"
            mixer_sigma(it, ai)
            break

        # Try to mix the hybridization functions
        @case "delta"
            mixer_delta(it, ai)
            break

        # Try to mix the local impurity levels
        @case "eimpx"
            mixer_eimpx(it, ai)
            break

        # Try to mix the density matrix
        @case "gamma"
            mixer_gamma(it)
            break

        @default
            sorry()
            break
    end

    # Monitor the status
    monitor(true)
end

#=
### *Service Functions* : *Layer 3*
=#

#=
*Remarks* :

The working directories include `dft`, `dmft1`, `dmft2`, and `impurity.i`.
If they exist already, it would be better to remove them at first.
=#

"""
    build_trees()

Prepare the working directories at advance.

See also: [`clear_trees`](@ref).
"""
function build_trees()
    # Build an array for folders
    dir_list = ["dft", "dmft1", "dmft2"]
    for i = 1:get_i("nsite")
        push!(dir_list, "impurity.$i")
    end

    # Go through these folders, create them one by one.
    for i in eachindex(dir_list)
        dir = dir_list[i]
        if isdir(dir)
            rm(dir, force = true, recursive = true)
        end
        mkdir(dir)
    end
end

"""
    clear_trees()

Remove the working directories finally.

See also: [`build_trees`](@ref).
"""
function clear_trees()
    # Build an array for folders
    dir_list = ["dft", "dmft1", "dmft2"]
    for i = 1:get_i("nsite")
        push!(dir_list, "impurity.$i")
    end

    # Go through these folders, remove them one by one.
    for i in eachindex(dir_list)
        dir = dir_list[i]
        if isdir(dir)
            rm(dir, force = true, recursive = true)
        end
    end
end

#=
*Service Functions*: *Layer 4* (*For IterInfo Struct*)
=#

"""
    incr_it(it::IterInfo)

Modify the internal counters in `IterInfo` struct. This function is
used in the one-shot DFT + DMFT calculations only.

See also: [`IterInfo`](@ref), [`zero_it`](@ref).
"""
function incr_it(it::IterInfo)
    @assert it.sc == 1
    it.I₃ = 1
    it.I₁ = it.I₁ + 1
    it.I₄ = it.I₄ + 1
    @assert it.I₁ ≤ it.M₃
end

"""
    incr_it(it::IterInfo, c::I64, v::I64)

Modify the internal counters in `IterInfo` struct. This function is
used in the fully charge self-consistent DFT + DMFT calculations only.

See also: [`IterInfo`](@ref), [`zero_it`](@ref).
"""
function incr_it(it::IterInfo, c::I64, v::I64)
    @assert it.sc == 2
    @assert c in (1, 2, 3)
    @assert v ≥ 1

    if c == 1
        @assert v ≤ it.M₁
        it.I₁ = v
        it.I₄ = it.I₄ + 1
    elseif c == 2
        @assert v ≤ it.M₂
        it.I₂ = v
        it.I₄ = it.I₄ + 1
    elseif c == 3
        @assert v ≤ it.M₃
        it.I₃ = v
    end
end

"""
    zero_it(it::IterInfo)

Reset the counters in the `IterInfo` struct.

See also: [`IterInfo`](@ref), [`incr_it`](@ref).
"""
function zero_it(it::IterInfo)
    it.I₁ = 0
    it.I₂ = 0
end

"""
    prev_it(it::IterInfo)

Return the iteration information for previous DFT + DMFT step. This
function is suitable for one-shot calculation mode.

See also: [`mixer_core`](@ref), [`incr_it`](@ref).
"""
function prev_it(it::IterInfo)
    @assert it.sc == 1
    @assert it.I₁ ≥ 2
    return it.I₃, it.I₁ - 1
end

"""
    prev_it(it::IterInfo, c::I64)

Return the iteration information for previous DFT + DMFT step. This
function is suitable for fully self-consistent calculation mode.

See also: [`mixer_core`](@ref), [`incr_it`](@ref).
"""
function prev_it(it::IterInfo, c::I64)
    @assert it.sc == 2
    @assert c in (1, 2)

    if c == 1
        list = [(i3,i1) for i1 = 1:it.M₁, i3 = 1:it.M₃]
        newlist = reshape(list, it.M₁ * it.M₃)
        ind = findfirst(x -> x == (it.I₃, it.I₁), newlist)
        @assert ind ≥ 2
        return newlist[ind - 1]
    else
        list = [(i3,i2) for i2 = 1:it.M₂, i3 = 1:it.M₃]
        newlist = reshape(list, it.M₂ * it.M₃)
        ind = findfirst(x -> x == (it.I₃, it.I₂), newlist)
        @assert ind ≥ 2
        return newlist[ind - 1]
    end
end

"""
    cntr_it(it::IterInfo)

Return the counters in the IterInfo struct as a format string.

See also: [`IterInfo`](@ref)
"""
function cntr_it(it::IterInfo)
    " [Cycle -> $(it.sc) : $(it.I₄) : $(it.I₃) : $(it.I₁) : $(it.I₂)] "
end

"""
    show_it(it::IterInfo, lr::Logger)

Try to record the iteration information in the `case.cycle` file.

See also: [`IterInfo`](@ref), [`Logger`](@ref).
"""
function show_it(it::IterInfo, lr::Logger)
    # Extract parameter `nsite`
    nsite = get_i("nsite")
    @assert nsite == length(it.nf)

    # Write the header
    if it.I₄ == 0
        # Write labels
        print(lr.cycle, "#    #    #    #    μ0          μ1          μ2          ")
        for t = 1:nsite
            print(lr.cycle, "Vdc$t        ")
        end
        print(lr.cycle, "Nlo1        Nlo2        ")
        for t = 1:nsite
            print(lr.cycle, "Nio$t        ")
        end
        print(lr.cycle, "Etot        ")
        println(lr.cycle, "C(C)    C(E)    C(S)")
        # Write separator
        println(lr.cycle, repeat('-', 3*8 + 4*5 + 6*12 + 24*nsite))
    # Write iteration information
    else
        @printf(lr.cycle, "%-5i", it.I₄)
        @printf(lr.cycle, "%-5i", it.I₃)
        @printf(lr.cycle, "%-5i", it.I₁)
        @printf(lr.cycle, "%-5i", it.I₂)
        #
        if it.μ₀ < 0.0
            @printf(lr.cycle, "%-12.7f", it.μ₀)
        else
            @printf(lr.cycle, "+%-11.7f", it.μ₀)
        end
        if it.μ₁ < 0.0
            @printf(lr.cycle, "%-12.7f", it.μ₁)
        else
            @printf(lr.cycle, "+%-11.7f", it.μ₁)
        end
        if it.μ₂ < 0.0
            @printf(lr.cycle, "%-12.7f", it.μ₂)
        else
            @printf(lr.cycle, "+%-11.7f", it.μ₂)
        end
        #
        for t = 1:nsite
            @printf(lr.cycle, "%-12.7f", it.dc[t])
        end
        #
        @printf(lr.cycle, "%-12.7f", it.n₁)
        @printf(lr.cycle, "%-12.7f", it.n₂)
        for t = 1:nsite
            @printf(lr.cycle, "%-12.7f", it.nf[t])
        end
        #
        @printf(lr.cycle, "%-12.7f", it.et)
        #
        @printf(lr.cycle, "%-8s", it.cc ? "true" : "false")
        @printf(lr.cycle, "%-8s", it.ce ? "true" : "false")
        @printf(lr.cycle, "%-8s", it.cs ? "true" : "false")
        #
        println(lr.cycle)
    end

    # Flush the IOStream
    flush(lr.cycle)
end

"""
    conv_it(it::IterInfo)

Check whether the convergence flags are achieved.

See also: [`IterInfo`](@ref).
"""
function conv_it(it::IterInfo)
    if it.sc == 1
        conv = it.cs
    else
        conv = it.cc && it.ce && it.cs
    end
    conv
end
