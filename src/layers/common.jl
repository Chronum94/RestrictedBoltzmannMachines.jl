const _ThetaLayers = Union{Binary, Spin, Potts, Gaussian, ReLU, pReLU, xReLU}
Base.size(layer::_ThetaLayers) = size(layer.θ)
Base.size(layer::_ThetaLayers, d::Int) = size(layer.θ, d)
Base.length(layer::_ThetaLayers) = length(layer.θ)

"""
    energies(layer, x)

Energies of units in layer (not reduced over layer dimensions).
"""
function energies(layer::Union{Binary,Spin,Potts}, x::AbstractArray)
    @assert size(layer) == size(x)[1:ndims(layer)]
    return -layer.θ .* x
end

function energy(layer::Union{Binary,Spin,Potts}, x::AbstractArray)
    @assert size(layer) == size(x)[1:ndims(layer)]
    xconv = activations_convert_maybe(layer.θ, x)
    if ndims(layer) == ndims(x)
        return -LinearAlgebra.dot(layer.θ, x)
    else
        Eflat = -vec(layer.θ)' * reshape(xconv, length(layer.θ), :)
        return reshape(Eflat, batchsize(layer, x))
    end
end

∂free_energy(layer::Union{Binary,Spin,Potts}) = (; θ = -transfer_mean(layer))

function ∂energy(layer::Union{Binary,Spin,Potts}; x::AbstractArray)
    @assert size(x) == size(layer)
    return (; θ = -x)
end

function sufficient_statistics(
    layer::Union{Binary,Spin,Potts},
    x::AbstractArray;
    wts = nothing
)
    @assert size(layer) == size(x)[1:ndims(layer)]
    return (; x = batchmean(layer, x; wts))
end

"""
    colors(layer)

Number of possible states of units in discrete layers.
"""
colors(layer::Union{Spin,Binary}) = 2
colors(layer::Potts) = size(layer, 1)

"""
    sitedims(layer)

Number of dimensions of layer, with special handling of Potts layer,
for which the first dimension doesn't count as a site dimension.
"""
sitedims(layer::AbstractLayer) = ndims(layer)
sitedims(layer::Potts) = ndims(layer) - 1

"""
    sitesize(layer)

Size of layer, with special handling of Potts layer,
for which the first dimension doesn't count as a site dimension.
"""
sitesize(layer::AbstractLayer) = size(layer)
sitesize(layer::Potts) = size(layer)[2:end]

function pReLU(layer::dReLU)
    γ = @. 2layer.γp * layer.γn / (layer.γp + layer.γn)
    η = @. (layer.γn - layer.γp) / (layer.γp + layer.γn)
    θ = @. (layer.θp * layer.γn + layer.θn * layer.γp) / (layer.γp + layer.γn)
    Δ = @. γ * (layer.θp - layer.θn) / (layer.γp + layer.γn)
    return pReLU(θ, γ, Δ, η)
end

function dReLU(layer::pReLU)
    γp = @. layer.γ / (1 + layer.η)
    γn = @. layer.γ / (1 - layer.η)
    θp = @. layer.θ + layer.Δ / (1 + layer.η)
    θn = @. layer.θ - layer.Δ / (1 - layer.η)
    return dReLU(θp, θn, γp, γn)
end

function xReLU(layer::dReLU)
    γ = @. 2layer.γp * layer.γn / (layer.γp + layer.γn)
    ξ = @. (layer.γn - layer.γp) / (layer.γp + layer.γn - abs(layer.γn - layer.γp))
    θ = @. (layer.θp * layer.γn + layer.θn * layer.γp) / (layer.γp + layer.γn)
    Δ = @. γ * (layer.θp - layer.θn) / (layer.γp + layer.γn)
    return xReLU(θ, γ, Δ, ξ)
end

function dReLU(layer::xReLU)
    ξp = @. (1 + abs(layer.ξ)) / (1 + max(2layer.ξ, 0))
    ξn = @. (1 + abs(layer.ξ)) / (1 - min(2layer.ξ, 0))
    γp = @. layer.γ * ξp
    γn = @. layer.γ * ξn
    θp = @. layer.θ + layer.Δ * ξp
    θn = @. layer.θ - layer.Δ * ξn
    return dReLU(θp, θn, γp, γn)
end

function xReLU(layer::pReLU)
    ξ = @. layer.η / (1 - abs(layer.η))
    return xReLU(layer.θ, layer.γ, layer.Δ, ξ)
end

function pReLU(layer::xReLU)
    η = @. layer.ξ / (1 + abs(layer.ξ))
    return pReLU(layer.θ, layer.γ, layer.Δ, η)
end

dReLU(layer::Gaussian) = dReLU(layer.θ, layer.θ, layer.γ, layer.γ)
pReLU(layer::Gaussian) = pReLU(dReLU(layer))
xReLU(layer::Gaussian) = xReLU(dReLU(layer))

#dReLU(layer::ReLU) = dReLU(layer.θ, zero(layer.θ), layer.γ, inf.(layer.γ))

# function pReLU(layer::ReLU)
#     θ = layer.θ
#     γ = 2layer.γ
#     η = one.(layer.γ)
#     Δ = zero.(layer.θ)
#     return pReLU(θ, γ, Δ, η)
# end

# function xReLU(layer::ReLU)
#     θ = layer.θ
#     γ = 2layer.γ
#     ξ = inf.(layer.γ)
#     Δ = zero.(layer.θ)
#     return xReLU(θ, γ, Δ, ξ)
# end
