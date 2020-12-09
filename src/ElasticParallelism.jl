module ElasticParallelism

using Distributed
using DataStructures


export ElasticityManager, @all_workers, addproc_elastic!, addprocs_elastic!

# TODO: Should this subtype AbstractWorkerPool
struct ElasticityManager
    pool::AbstractWorkerPool
    worker_setups::Vector  # this is code that is set to run on all workers
end

function ElasticityManager(pool=WorkerPool())
    return ElasticityManager(pool, Any[])
end

const GLOBAL_ELASTICITY_MANAGER = Ref(ElasticityManager())


Distributed.workers(em::ElasticityManager) = workers(em.pool)

include("all_workers.jl")
include("addprocs.jl")
include("pmap.jl")

end # module
