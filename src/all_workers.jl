
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
