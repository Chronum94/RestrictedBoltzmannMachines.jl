using Test: @test, @testset, @inferred
using Statistics: mean, std, var
using Random: randn!
using LogExpFunctions: logsumexp
using RestrictedBoltzmannMachines: BinaryRBM, energy, free_energy, transfer_sample
using RestrictedBoltzmannMachines: anneal, ais, log_partition_zero_weight
using RestrictedBoltzmannMachines: Binary, Spin, Potts, Gaussian, ReLU, dReLU, xReLU, pReLU

@testset "log_partition_zero_weight" begin
    rbm = BinaryRBM(randn(3), randn(2), zeros(3,2))
    lZ = logsumexp(-energy(rbm, [v1,v2,v3], [h1,h2]) for v1 in 0:1, v2 in 0:1, v3 in 0:1, h1 in 0:1, h2 in 0:1)
    randn!(rbm.w)
    @test log_partition_zero_weight(rbm) ≈ lZ
end

@testset "AIS for binary RBM" begin
    rbm = BinaryRBM(randn(3), randn(2), randn(3,2))
    for v1 in 0:1, v2 in 0:1, v3 in 0:1
        @test free_energy(rbm, [v1,v2,v3]) ≈ -logsumexp(-energy(rbm, [v1,v2,v3], [h1,h2]) for h1 in 0:1, h2 in 0:1)
    end

    lZ = logsumexp(-energy(rbm, [v1,v2,v3], [h1,h2]) for v1 in 0:1, v2 in 0:1, v3 in 0:1, h1 in 0:1, h2 in 0:1)
    @test logsumexp(-free_energy(rbm, [v1,v2,v3]) for v1 in 0:1, v2 in 0:1, v3 in 0:1) ≈ lZ

    @test ais(rbm; nbetas=10000, nsamples=100) ≈ lZ  rtol=0.1
end

@testset "anneal layer" begin
    β = 0.3
    N = 11

    init = Binary(randn(N))
    final = Binary(randn(N))
    null = Binary(zeros(N))
    x = transfer_sample(final)
    @test energy(anneal(init, final; β), x) ≈ (1 - β) * energy(init, x) + β * energy(final, x)
    @test energy(anneal(final; β), x) ≈ energy(anneal(null, final; β), x)

    init = Spin(randn(N))
    final = Spin(randn(N))
    null = Spin(zeros(N))
    x = transfer_sample(final)
    @test energy(anneal(init, final; β), x) ≈ (1 - β) * energy(init, x) + β * energy(final, x)
    @test energy(anneal(final; β), x) ≈ energy(anneal(null, final; β), x)

    init = Potts(randn(N))
    final = Potts(randn(N))
    null = Potts(zeros(N))
    x = transfer_sample(final)
    @test energy(anneal(init, final; β), x) ≈ (1 - β) * energy(init, x) + β * energy(final, x)
    @test energy(anneal(final; β), x) ≈ energy(anneal(null, final; β), x)

    init = Gaussian(randn(N), rand(N))
    final = Gaussian(randn(N), init.γ)
    null = Gaussian(zeros(N), init.γ)
    x = transfer_sample(final)
    @test energy(anneal(init, final; β), x) ≈ (1 - β) * energy(init, x) + β * energy(final, x)
    @test energy(anneal(final; β), x) ≈ energy(anneal(null, final; β), x)

    init = ReLU(randn(N), rand(N))
    final = ReLU(randn(N), init.γ)
    null = ReLU(zeros(N), init.γ)
    x = transfer_sample(final)
    @test energy(anneal(init, final; β), x) ≈ (1 - β) * energy(init, x) + β * energy(final, x)
    @test energy(anneal(final; β), x) ≈ energy(anneal(null, final; β), x)

    init = dReLU(randn(N), randn(N), rand(N), rand(N))
    final = dReLU(randn(N), randn(N), init.γp, init.γn)
    null = dReLU(zeros(N), zeros(N), init.γp, init.γn)
    x = transfer_sample(final)
    @test energy(anneal(init, final; β), x) ≈ (1 - β) * energy(init, x) + β * energy(final, x)
    @test energy(anneal(final; β), x) ≈ energy(anneal(null, final; β), x)

    init = pReLU(randn(N), rand(N), randn(N), rand(N) .- 0.5)
    final = pReLU(randn(N), init.γ, randn(N), init.η)
    null = pReLU(zeros(N), init.γ, zeros(N), init.η)
    x = transfer_sample(final)
    @test energy(anneal(init, final; β), x) ≈ (1 - β) * energy(init, x) + β * energy(final, x)
    @test energy(anneal(final; β), x) ≈ energy(anneal(null, final; β), x)

    init = xReLU(randn(N), rand(N), randn(N), randn(N))
    final = xReLU(randn(N), init.γ, randn(N), init.ξ)
    null = xReLU(zeros(N), init.γ, zeros(N), init.ξ)
    x = transfer_sample(final)
    @test energy(anneal(init, final; β), x) ≈ (1 - β) * energy(init, x) + β * energy(final, x)
    @test energy(anneal(final; β), x) ≈ energy(anneal(null, final; β), x)
end