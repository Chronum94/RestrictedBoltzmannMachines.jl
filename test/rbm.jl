import Statistics
import Random
import Zygote
import RestrictedBoltzmannMachines as RBMs

using Test: @test, @testset
using Random: bitrand, randn!
using Statistics: mean
using LinearAlgebra: logdet, diag, diagm, dot, isposdef
using LogExpFunctions: logsumexp
using QuadGK: quadgk
using RestrictedBoltzmannMachines: BinaryRBM, energy, interaction_energy, free_energy
using RestrictedBoltzmannMachines: inputs_h_from_v, inputs_v_from_h, inputs_v_to_h, inputs_h_to_v

@testset "batches, n=$n, m=$m, Bv=$Bv, Bh=$Bh" for n in (5, (5,2)), m in (2, (3,4)), Bv in ((), (3,2)), Bh in ((), (3,2))
    rbm = RBMs.BinaryRBM(randn(n...), randn(m...), randn(n..., m...))
    wmat = reshape(rbm.w, length(rbm.visible), length(rbm.hidden))
    v = bitrand(n..., Bv...)
    h = bitrand(m..., Bh...)

    @test RBMs.batch_size(rbm.visible, v) == Bv
    @test RBMs.batch_size(rbm.hidden, h) == Bh

    @test size(inputs_h_from_v(rbm, v)) == (size(rbm.hidden)...,  Bv...)
    @test size(inputs_v_from_h(rbm, h)) == (size(rbm.visible)..., Bh...)
    @test inputs_h_from_v(rbm, v) == inputs_v_to_h(rbm, v)
    @test inputs_v_from_h(rbm, h) == inputs_h_to_v(rbm, h)

    if length(Bv) == length(Bh) == 0
        @test interaction_energy(rbm, v, h) isa Number
        @test interaction_energy(rbm, v, h) ≈ -vec(v)' * wmat * vec(h)
        @test energy(rbm, v, h) isa Number
    elseif length(Bv) == 0
        hmat = reshape(h, length(rbm.hidden), :)
        E = -vec(v)' * wmat * hmat
        @test interaction_energy(rbm, v, h) isa AbstractArray
        @test size(interaction_energy(rbm, v, h)) == Bh
        @test interaction_energy(rbm, v, h) ≈ reshape(E, Bh)
        @test size(energy(rbm, v, h)) == Bh
    elseif length(Bh) == 0
        vmat = reshape(v, length(rbm.visible), :)
        E = -vec(h)' * wmat' * vmat
        @test interaction_energy(rbm, v, h) isa AbstractArray
        @test size(interaction_energy(rbm, v, h)) == Bv
        @test interaction_energy(rbm, v, h) ≈ reshape(E, Bv)
        @test size(energy(rbm, v, h)) == Bv
    else
        vmat = reshape(v, length(rbm.visible), :)
        hmat = reshape(h, length(rbm.hidden), :)
        E = -dot.(eachcol(vmat), Ref(wmat), eachcol(hmat))
        @test interaction_energy(rbm, v, h) isa AbstractArray
        @test size(interaction_energy(rbm, v, h)) == Bv == Bh
        @test interaction_energy(rbm, v, h) ≈ reshape(E, Bv)
        @test size(energy(rbm, v, h)) == Bv == Bh
    end
    @inferred inputs_h_from_v(rbm, v)
    @inferred inputs_v_from_h(rbm, h)
    @inferred interaction_energy(rbm, v, h)
    @inferred energy(rbm, v, h)
    gs = Zygote.gradient(rbm) do rbm
        mean(energy(rbm, v, h))
    end
    ∂w = @inferred RBMs.∂interaction_energy(rbm, v, h)
    @test ∂w ≈ only(gs).w
end

@testset "singleton batch dims" begin # behavior useful for ConvolutionalRBMs.jl
    rbm = RBMs.BinaryRBM(randn(3), randn(2), randn(3,2))

    v = bitrand(3,1,2)
    h = bitrand(2,3,1)
    @test size(energy(rbm, v, h)) == @inferred(RBMs.batch_size(rbm, v, h)) == (3,2)
    @test energy(rbm, v, h) ≈ [energy(rbm, v[:,1,j], h[:,i,1]) for i = 1:3, j = 1:2]

    v = bitrand(3,1,2)
    h = bitrand(2,3)
    @test size(energy(rbm, v, h)) == @inferred(RBMs.batch_size(rbm, v, h)) == (3,2)
    @test energy(rbm, v, h) ≈ [energy(rbm, v[:,1,j], h[:,i]) for i = 1:3, j = 1:2]

    v = bitrand(3,1)
    h = bitrand(2,3,2)
    @test size(energy(rbm, v, h)) == @inferred(RBMs.batch_size(rbm, v, h)) == (3,2)
    @test energy(rbm, v, h) ≈ [energy(rbm, v[:,1], h[:,i,j]) for i = 1:3, j = 1:2]

    v = bitrand(3,1,2)
    h = bitrand(2,3,2)
    @test size(energy(rbm, v, h)) == @inferred(RBMs.batch_size(rbm, v, h)) == (3,2)
    @test energy(rbm, v, h) ≈ [energy(rbm, v[:,1,j], h[:,i,j]) for i = 1:3, j = 1:2]

    v = bitrand(3,3,1)
    h = bitrand(2,3,2)
    @test size(energy(rbm, v, h)) == @inferred(RBMs.batch_size(rbm, v, h)) == (3,2)
    @test energy(rbm, v, h) ≈ [energy(rbm, v[:,i,1], h[:,i,j]) for i = 1:3, j = 1:2]

    v = bitrand(3,2,2)
    h = bitrand(2,3,1)
    @test_throws Any RBMs.batch_size(rbm, v, h)
    @test_throws Any energy(rbm, v, h)

    v = bitrand(3,1,2)
    h = bitrand(2,3,3)
    @test_throws Any RBMs.batch_size(rbm, v, h)
    @test_throws Any energy(rbm, v, h)
end

@testset "sample_v_from_v and sample_h_from_h on binary RBM" begin
    rbm = RBMs.BinaryRBM(randn(3,2), randn(2,3), zeros(3,2,2,3))
    v = bitrand(size(rbm.visible)..., 10^6)
    v = RBMs.sample_v_from_v(rbm, v)
    @test RBMs.batchmean(rbm.visible, v) ≈ RBMs.mean_from_inputs(rbm.visible) rtol=0.1

    h = bitrand(size(rbm.hidden)...,  10^6)
    h = RBMs.sample_h_from_h(rbm, h)
    @test RBMs.batchmean(rbm.hidden, h) ≈ RBMs.mean_from_inputs(rbm.hidden) rtol=0.1

    randn!(rbm.w)
    h = RBMs.sample_h_from_v(rbm, v)
    μ = RBMs.mean_from_inputs(rbm.hidden, inputs_h_from_v(rbm, v))
    @test RBMs.batchmean(rbm.hidden, h) ≈ RBMs.batchmean(rbm.hidden, μ) rtol=0.1

    randn!(rbm.w)
    v = RBMs.sample_v_from_h(rbm, h)
    μ = RBMs.mean_from_inputs(rbm.visible, inputs_v_from_h(rbm, h))
    @test RBMs.batchmean(rbm.visible, v) ≈ RBMs.batchmean(rbm.visible, μ) rtol=0.1
end

@testset "rbm convenience constructors" begin
    rbm = RBMs.BinaryRBM(randn(5), randn(3), randn(5,3))
    @test rbm.visible isa RBMs.Binary
    @test rbm.hidden isa RBMs.Binary
    @test size(rbm.w) == (5,3)

    rbm = RBMs.HopfieldRBM(randn(5), randn(3), rand(3), randn(5,3))
    @test rbm.visible isa RBMs.Spin
    @test rbm.hidden isa RBMs.Gaussian
    @test size(rbm.w) == (5,3)
    @test all(rbm.hidden.γ .> 0)

    rbm = RBMs.HopfieldRBM(randn(5), randn(5,3))
    @test rbm.visible isa RBMs.Spin
    @test iszero(RBMs.mean_from_inputs(rbm.hidden))
    @test RBMs.var_from_inputs(rbm.hidden) == ones(size(rbm.hidden))
    @test size(rbm.w) == (5,3)
end

@testset "Binary-Binary RBM" begin
    rbm = RBMs.BinaryRBM(randn(5,2), randn(4,3), randn(5,2,4,3))
    v = rand(Bool, size(rbm.visible)..., 7)
    h = rand(Bool, size(rbm.hidden)..., 7)
    @test size(@inferred interaction_energy(rbm, v, h)) == (7,)
    @test size(@inferred energy(rbm, v, h)) == (7,)

    Ew = -[sum(v[i,j,b] * rbm.w[i,j,μ,ν] * h[μ,ν,b] for i=1:5, j=1:2, μ=1:4, ν=1:3) for b=1:7]
    @test interaction_energy(rbm, v, h) ≈ Ew
    @test energy(rbm, v, h) ≈ energy(rbm.visible, v) + energy(rbm.hidden, h) + Ew

    @test (@inferred energy(rbm, v[:,:,1], h[:,:,1])) isa Real
    @test (@inferred energy(rbm, v[:,:,1], h)) isa AbstractVector{<:Real}
    @test (@inferred energy(rbm, v, h[:,:,1])) isa AbstractVector{<:Real}

    for b = 1:7
        @test energy(rbm, v[:,:,b], h[:,:,b]) ≈ energy(rbm, v, h)[b]
        @test energy(rbm, v[:,:,b], h) ≈ [energy(rbm, v[:,:,b], h[:,:,k]) for k=1:7]
        @test energy(rbm, v, h[:,:,b]) ≈ [energy(rbm, v[:,:,k], h[:,:,b]) for k=1:7]
    end

    @test size(@inferred RBMs.sample_h_from_v(rbm, v)) == size(h)
    @test size(@inferred RBMs.sample_v_from_h(rbm, h)) == size(v)
    @test size(@inferred RBMs.sample_h_from_v(rbm, v[:,:,1])) == size(rbm.hidden)
    @test size(@inferred RBMs.sample_v_from_h(rbm, h[:,:,1])) == size(rbm.visible)
    for k = 1:3
        @test size(@inferred RBMs.sample_v_from_v(rbm, v; steps=k)) == size(v)
        @test size(@inferred RBMs.sample_h_from_h(rbm, h; steps=k)) == size(h)
        @test size(@inferred RBMs.sample_v_from_v(rbm, v[:,:,1]; steps=k)) == size(rbm.visible)
        @test size(@inferred RBMs.sample_h_from_h(rbm, h[:,:,1]; steps=k)) == size(rbm.hidden)
    end

    @test size(@inferred RBMs.mean_h_from_v(rbm, v)) == size(h)
    @test size(@inferred RBMs.mean_v_from_h(rbm, h)) == size(v)
    @test size(@inferred RBMs.mean_h_from_v(rbm, v[:,:,1])) == size(rbm.hidden)
    @test size(@inferred RBMs.mean_v_from_h(rbm, h[:,:,1])) == size(rbm.visible)

    @test size(@inferred RBMs.mode_h_from_v(rbm, v)) == size(h)
    @test size(@inferred RBMs.mode_v_from_h(rbm, h)) == size(v)
    @test size(@inferred RBMs.mode_h_from_v(rbm, v[:,:,1])) == size(rbm.hidden)
    @test size(@inferred RBMs.mode_v_from_h(rbm, h[:,:,1])) == size(rbm.visible)

    @test size(@inferred RBMs.var_h_from_v(rbm, v)) == size(h)
    @test size(@inferred RBMs.var_v_from_h(rbm, h)) == size(v)
    @test size(@inferred RBMs.var_h_from_v(rbm, v[:,:,1])) == size(rbm.hidden)
    @test size(@inferred RBMs.var_v_from_h(rbm, h[:,:,1])) == size(rbm.visible)

    @test size(@inferred free_energy(rbm, v)) == (7,)
    @test size(@inferred RBMs.reconstruction_error(rbm, v)) == (7,)
    @test (@inferred free_energy(rbm, v[:,:,1])) isa Real
    @test (@inferred RBMs.reconstruction_error(rbm, v[:,:,1])) isa Real

    @inferred RBMs.mirror(rbm)
    @test RBMs.mirror(rbm).visible == rbm.hidden
    @test RBMs.mirror(rbm).hidden == rbm.visible
    @test energy(RBMs.mirror(rbm), h, v) ≈ energy(rbm, v, h)
end

@testset "binary free energy" begin
    rbm = RBMs.BinaryRBM(randn(1), randn(1), randn(1,1))
    for v in [[0], [1]]
        @test -free_energy(rbm, v) ≈ logsumexp(-energy(rbm, v, h) for h in [[0], [1]])
    end

    rbm = RBMs.BinaryRBM(randn(7), randn(2), randn(7,2))
    v = bitrand(7)
    hs = [[0,0], [0,1], [1,0], [1,1]]
    @test -free_energy(rbm, v) ≈ logsumexp(-energy(rbm, v, h) for h in hs)
end

@testset "Gaussian-Gaussian RBM, 1-dimension" begin
    rbm = RBMs.RBM(
        RBMs.Gaussian(randn(1), rand(1) .+ 1),
        RBMs.Gaussian(randn(1), rand(1) .+ 1),
        randn(1, 1) / 1e2
    )

    @assert isposdef([
        rbm.visible.γ -rbm.w;
        -rbm.w'  rbm.hidden.γ
    ])

    Z, ϵ = quadgk(x -> exp(-only(free_energy(rbm, [x;;]))), -Inf, Inf)
    @test RBMs.log_partition(rbm) ≈ log(Z)
end

@testset "Gaussian-Gaussian RBM, multi-dimensional" begin
    n = (10, 3)
    m = (7, 2)
    rbm = RBMs.RBM(
        RBMs.Gaussian(randn(n...), rand(n...) .+ 0.5),
        RBMs.Gaussian(randn(m...), rand(m...) .+ 0.5),
        randn(n..., m...) / (10 * prod(n) * prod(m))
    )

    N = length(rbm.visible)
    M = length(rbm.hidden)

    θ = [
        vec(rbm.visible.θ);
        vec(rbm.hidden.θ)
    ]
    γv = vec(rbm.visible.γ)
    γh = vec(rbm.hidden.γ)
    w = reshape(rbm.w, length(rbm.visible), length(rbm.hidden))
    A = [diagm(γv) -w;
         -w'  diagm(γh)]

    v = randn(n..., 1)
    h = randn(m..., 1)
    x = [reshape(v, N, 1); reshape(h, M, 1)]

    @test energy(rbm, v, h) ≈ x' * A * x / 2 - θ' * x
    @test RBMs.log_partition(rbm) ≈ (
        (N + M)/2 * log(2π) + θ' * inv(A) * θ / 2 - logdet(A)/2
    )
    @test RBMs.log_likelihood(rbm, v) ≈ -free_energy(rbm, v) .- RBMs.log_partition(rbm)

    Ev = sum(rbm.visible.γ .* v.^2 ./ 2 - rbm.visible.θ .* v)
    Fv = sum(-(rbm.hidden.θ .+ inputs_h_from_v(rbm, v)).^2 ./ 2rbm.hidden.γ)
    @test only(free_energy(rbm, v)) ≈ Ev + Fv - sum(log.(2π ./ rbm.hidden.γ)) / 2

    gs = Zygote.gradient(rbm) do rbm
        RBMs.log_partition(rbm)
    end
    ∂θv = vec(only(gs).visible.θ)
    ∂θh = vec(only(gs).hidden.θ)
    ∂γv = vec(only(gs).visible.γ)
    ∂γh = vec(only(gs).hidden.γ)
    ∂w = reshape(only(gs).w, length(rbm.visible), length(rbm.hidden))

    Σ = inv(A) # covariances
    μ = Σ * θ  # means
    C = Σ + μ * μ' # non-centered second moments

    @test [∂θv; ∂θh] ≈ μ
    @test -2∂γv ≈ diag(C[1:N, 1:N]) # <vi^2>
    @test -2∂γh ≈ diag(C[(N + 1):end, (N + 1):end]) # <hμ^2>
    @test ∂w ≈ C[1:N, (N + 1):end] # <vi*hμ>
end

@testset "zero hidden units" begin
    rbm = BinaryRBM(randn(5), randn(0), randn(5,0))
    v = bitrand(5)
    @test free_energy(rbm, v) ≈ energy(rbm.visible, v)
end
