"""
    ∂reg!(∂, rbm; l2_fields = 0, l1_weights = 0, l2_weights = 0, l2l1_weights = 0)

Updates RBM gradients `∂`, with the regularization gradient.
"""
function ∂regularize!(
    ∂::NamedTuple, # unregularized gradient
    rbm::RBM{<:Union{Binary,Spin,Potts,Gaussian,ReLU,xReLU,pReLU}};
    l2_fields::Real = 0, # L2 regularization of visible unit fields
    l1_weights::Real = 0, # L1 regularization of weights
    l2_weights::Real = 0, # L2 regularization of weights
    l2l1_weights::Real = 0 # L2/L1 regularziation of weights (10.7554/eLife.39397, Eq. 8)
)
    if !iszero(l2_fields)
        ∂regularize_fields!(∂.visible, visible(rbm); l2_fields)
    end
    if !iszero(l1_weights)
        ∂.w .+= l1_weights * sign.(weights(rbm))
    end
    if !iszero(l2_weights)
        ∂.w .+= l2_weights * weights(rbm)
    end
    if !iszero(l2l1_weights)
        dims = ntuple(identity, ndims(visible(rbm)))
        ∂.w .+= l2l1_weights * sign.(weights(rbm)) .* mean(abs, weights(rbm); dims)
    end
    return ∂
end

function ∂regularize_fields!(
    ∂::NamedTuple, layer::Union{Binary,Spin,Potts,Gaussian,ReLU,xReLU,pReLU}; l2_fields::Real = 0
)
    if !iszero(l2_fields)
        ∂.θ .+= l2_fields * layer.θ
    end
    return ∂
end

function ∂regularize_fields!(∂::NamedTuple, layer::dReLU; l2_fields::Real = 0)
    if !iszero(l2_fields)
        ∂.θp .+= l2_fields * layer.θp
        ∂.θn .+= l2_fields * layer.θn
    end
    return ∂
end
