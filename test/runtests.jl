using ElasticParallelism
using Test
using Distributed

@testset "1" begin
    em = ElasticityManager()
    @test length(workers(em)) == 0
    addproc_elastic!(em)
    sleep(2)
    @test length(workers(em)) == 1

    @all_workers em begin
        using Distributed
        global x = 2myid()
    end
    
    for worker_id in workers(em)
        @test 2*worker_id == remotecall_fetch(worker_id) do
            x
        end
    end
    
    addproc_elastic!(em)
    sleep(2)
    @test length(workers(em)) == 2
    
    for worker_id in workers(em)
        @test 2*worker_id == remotecall_fetch(worker_id) do
            x
        end
    end

end
