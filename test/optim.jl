using Test: @test, @testset, @inferred
import RestrictedBoltzmannMachines as RBMs
using Random: bitrand
using RestrictedBoltzmannMachines: RBM, BinaryRBM, ∂free_energy, ∂RBM,
    Binary, Spin, Potts, Gaussian, ReLU, dReLU, pReLU, xReLU

@testset "∂ operations" begin
    ∂1 = ∂RBM(randn(1,3), randn(1,2), randn(3,2))
    ∂2 = ∂RBM(randn(1,3), randn(1,2), randn(3,2))
    @test @inferred(∂1 + ∂2) == ∂RBM(∂1.visible + ∂2.visible, ∂1.hidden + ∂2.hidden, ∂1.w + ∂2.w)
    @test @inferred(∂1 - ∂2) == ∂RBM(∂1.visible - ∂2.visible, ∂1.hidden - ∂2.hidden, ∂1.w - ∂2.w)
    @test @inferred(2∂1) == ∂RBM(2∂1.visible, 2∂1.hidden, 2∂1.w)
end
