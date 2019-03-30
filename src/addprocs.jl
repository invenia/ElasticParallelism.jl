
function addproc_elastic(em::ElasticityManager)
    @async begin
        # Add the worker
        proc_id::Integer = first(addprocs(1))
        # TODO Support cluster mangers
        
        # setup the worker
        for code in em.worker_setups
            remotecall_fetch(proc_id) do  # use the blocking version as am already async
                eval(code)
            end
        end

        # make the worker available to the cluster_manager
        push!(em.pool, proc_id)
    end
end



function Distributed.addprocs(em::ElasticityManager, nprocs)
    return addprocs_elastic(em::ElasticityManager, nprocs)
end

function addprocs_elastic(nprocs::Integer)
    addprocs_elastic(GLOBAL_ELASTICITY_MANAGER[], nprocs)
end



function addprocs_elastic(em::ElasticityManager, nprocs)
    for ii in 1:nprocs
        @async addproc_elastic(em)
    end
end

