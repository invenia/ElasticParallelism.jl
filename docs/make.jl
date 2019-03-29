using Documenter, ElasticParallelism

makedocs(;
    modules=[ElasticParallelism],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/invenia/ElasticParallelism.jl/blob/{commit}{path}#L{line}",
    sitename="ElasticParallelism.jl",
    authors="Invenia Technical Computing Corporation",
    assets=[
        "assets/invenia.css",
        "assets/logo.png",
    ],
)

deploydocs(;
    repo="github.com/invenia/ElasticParallelism.jl",
)
