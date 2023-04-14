using Finch
using Documenter
using Literate

DocMeta.setdocmeta!(Finch, :DocTestSetup, :(using Finch; using SparseArrays); recursive=true)

Literate.notebook(joinpath(@__DIR__, "src/usage.jl"), joinpath(@__DIR__, "../binder"))

makedocs(;
    modules=[Finch],
    authors="Willow Ahrens",
    repo="https://github.com/willow-ahrens/Finch.jl/blob/{commit}{path}#{line}",
    sitename="Finch.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://willow-ahrens.github.io/Finch.jl",
        assets=["assets/favicon.ico"],
    ),
    pages=[
        "Home" => "index.md",
        "Array Formats" => "fibers.md",
        "The Deets" => "listing.md",
        "Embedding" => "embed.md",
        "Custom Functions" => "algebra.md",
        "Development Guide" => "development.md",
    ],
)

deploydocs(;
    repo="github.com/willow-ahrens/Finch.jl",
    devbranch="main",
)