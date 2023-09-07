# Directory Structure

Here's a little roadmap to the Finch codebase! Please file an issue if this is
not up to date.

```
.
├── apps                       # Example applications implemented in Finch!
│   ├── graphs.jl              # Graph Algorithms: Pagerank, Bellman-Ford, etc...
│   ├── linalg.jl              # Linear Algebra: Sparse-Sparse Matmul, etc...
│   └── ...
├── benchmark                  # benchmarks for internal use
│   ├── runbenchmarks.jl       # run benchmarks
│   ├── runjudge.jl            # run benchmarks on current branch and compare with main
│   └── ...                 
├── docs                       # documentation
│   ├── [build]                # rendered docs website
│   ├── src                    # docs website source
│   ├── fix.jl                 # fix docstrings
│   ├── make.jl                # build documentation locally
│   └── ...                 
├── embed                      # wrappers for embedding Finch in C
├── ext                        # conditionally-loaded code for interaction with other packages (e.g. SparseArrays)
├── src                        # Source files
│   ├── base                   # Implementations of base functions (e.g. map, reduce, etc.)
│   ├── fileio                 # File IO function definitions
│   ├── FinchNotation          # SubModule containing the Finch IR
│   │   ├── nodes.jl           # defines the Finch IR
│   │   ├── syntax.jl          # defines the @finch frontend syntax
│   │   └── ...
│   ├── looplets               # this is where all the Looplets live
│   ├── symbolic               # term rewriting systems for program and bounds
│   ├── tensors                # built-in Finch tensor definitions
│   │   ├── levels             # all of the levels
│   │   ├── fibers.jl          # fibers combine levels to form tensors
│   │   ├── scalars.jl         # a nice scalar type
│   │   └── masks.jl           # mask tensors (e.g. upper-triangular mask)
│   ├── transformations        # global program transformations
│   │   ├── scopes.jl          # gives unique names to indices
│   │   ├── lifetimes.jl       # adds freeze and thaw
│   │   ├── dimensionalize.jl  # computes extents for loops and declarations
│   │   ├── concordize.jl      # adds loops to ensure all accesses are concordant
│   │   └── wrapperize.jl      # converts index expressions to array wrappers
│   ├──  execute.jl            # global compiler calls
│   ├──  lower.jl              # inner compiler definition
│   ├──  semantics.jl          # finch array interface functions
│   ├──  traits.jl             # functions and types to reason about appropriate outputs
│   ├──  util.jl               # shims and julia codegen utils (Dead code elimination, etc...)
│   └── ...
├── test                       # tests
│   ├──  embed                 # tests for the C embedding. Optional build before runtests.jl
│   ├──  reference32           # reference output for 32-bit systems
│   ├──  reference64           # reference output for 64-bit systems
│   ├──  runtests.jl           # runs the test suite. (pass -h for options and more info!)
│   └── ...
├── Project.toml               # julia-readable listing of project dependencies
├── [Manifest.toml]            # local listing of installed dependencies (don't commit this)
├── LICENSE
└── README.md
```