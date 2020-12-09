function Distributed.pmap(f, em::ElasticityManager, data; nchunks=25)
    # Work must be pushed to each worker
    # We cannot use a workers pull model (e.g with `Channels`)
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

