module ElasticParallelism

using Distributed
using DataStructures

# TODO: Should this subtype AbstractWorkerPool
struct ElasticityManager
    pool::AbstractWorkerPool
    worker_setups::Vector  # this is code that is set to run on all workers
end

function ElasticityManager(pool)
    return ElasticityManager(pool, Any[])
end


function ElasticityManager()
    return ElasticityManager(WorkerPool())
end

const GLOBAL_ELASTICITY_MANAGER = Ref(ElasticityManager())


"""
    @all_workers

Basically the same as @everywhere,
but allows the elasticity_manager to know what new workers  should
run as they come on-line.
"""
macro all_workers(elasticity_manager, expr)
    quote
        em = $(esc(elasticity_manager))
        # Save it for future workers
        push!(em.worker_setups, $(esc(expr)))

        # run it on current workers now
        for worker in workers(em.pool)
            remotecall(worker) do
                eval($(esc(expr)))
            end
        end
    end
end

#== TODO: Work this one out
macro all_workers(expr)
    return esc(:($(@all_workers)($(GLOBAL_ELASTICITY_MANAGER[]), $expr)))
end
==#

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

function Distributed.pmap(f, em::ElasticityManager, data; nchunks=25)
    # Work mush be pushed to each worker
    # We can not use a workers pull model (e.g with channels)
    # because we need to track who was doing what work,
    # incase the worker dies and we need to reassign it.

    # Partition the work into reasonable chunks.
    # This Dict holds the work even after it has been deployed to a worker
    # So that if that worker dies, then we can later redloy it elsewhere
    all_work = SortedDict(enumerate(Base.Iterators.partition(data, nchunks)))
    
    pending_work = collect(all_work)  # Initially has everything on it.

    future_results = Vector{Pair{Int, Future}}()  # ChunkID => Future
    results = SortedDict{Int, Vector}()

    # loop until all the work we wanted done has arrived in our `results`
    @sync while length(results) < length(all_work)
        # IN THIS LOOP:
        # Give unassigned workers work, tracking who has what in the future_results Dict
        # and:
        # Check the future results Dict for complete work, and fetch it
        # Check the future results for dead workers, if if so reassign that work.
        
        # Work feeder
        @async if !isempty(pending_work)
            chunk_id, chunk = pop!(pending_work)
            future_results[chunk_id] = remotecall(f, em.pool, chunk)
        end

        # Future checker
        @async if !isempty(future_results)
            # We remove it so we can start other asyncs to check the second element etc
            chunk_id, future = pop!(future_results)
            try
                if isready(future)
                    results[chunk_id] = fetch(future)
                else
                    # add to end of queue so we don't just recheck this one
                    # again and again
                    pushfirst!(future_results, (chunk_id=>future))
                end
            catch err
                err isa Distributed.ProcessExitedException || rethrow()
                # This worker is dead, need to reschedule it's work
                chunk = all_work[chunk_id]
                # put it at the end of queue incase this work is killing workers
                # then at least others will get done first.

                pushfirst!(pending_work, chunk_id=>chunk)
                
                # The standard worker pool stuff will make sure not to
                # allocate any more work to this worker in the future.
            end
        end
    end
    # It is already in the right order as we used a `SortedDict`
    return reduce(vcat, values(results))
end

end # module
