function addproc_elastic!(em::ElasticityManager)
    @async begin
        # Add the worker
        proc_id::Integer = first(addprocs(1))
        # TODO Support cluster mangers
        
        # setup the worker
        for code in em.worker_setups
            # use the blocking version as am already async
            # and we don't want the worker added to the pool
            # til this is ready
            remotecall_wait(Core.eval, proc_id, Main, code)
        end

        # make the worker available to the cluster_manager
        push!(em.pool, proc_id)
    end
end


function addprocs_elastic!(nprocs::Integer)
    addprocs_elastic(GLOBAL_ELASTICITY_MANAGER[], nprocs)
end



function addprocs_elastic!(em::ElasticityManager, nprocs)
    for ii in 1:nprocs
        @async addproc_elastic!(em)
    end
end

