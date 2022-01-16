"""
    cd!(rbm, data)

Trains the RBM on data using contrastive divergence.
"""
function cd!(rbm::RBM, data::AbstractArray;
    batchsize = 1,
    epochs = 1,
    optimizer = default_optimizer(_nobs(data), batchsize, epochs), # optimizer algorithm
    history::MVHistory = MVHistory(), # stores training log
    verbose::Bool = true,
    wts = nothing, # data point weights
    steps::Int = 1, # Monte Carlo steps to update fantasy particles
)
    @assert size(data) == (size(rbm.visible)..., size(data)[end])
    @assert isnothing(wts) || _nobs(data) == _nobs(wts)

    ts = sufficient_statistics(rbm.visible, data; wts)

    for epoch in 1:epochs
        batches = minibatches(data, wts; batchsize = batchsize)
        Δt = @elapsed for (vd, wd) in batches
            # new fantasy chains
            _idx = rand(1:_nobs(data), batchsize)
            _vm = copy(selectdim(data, ndims(data), _idx))
            vm = sample_v_from_v(rbm, _vm; steps = steps)
            # compute gradients
            ∂ = ∂contrastive_divergence(rbm, vd, vm; wd = wd, wm = wd, ts)
            # update parameters with gradients
            update!(optimizer, rbm, ∂)
        end

        lpl = wmean(log_pseudolikelihood(rbm, data); wts)
        push!(history, :lpl, lpl)
        push!(history, :epoch, epoch)
        push!(history, :Δt, Δt)
        if verbose
            Δt_ = round(Δt, digits=2)
            lpl_ = round(lpl, digits=2)
            println("epoch $epoch/$epochs ($(Δt_)s), log(PL)=$lpl_")
        end
    end
    return history
end

"""
    contrastive_divergence(rbm, vd, vm; wd = 1, wm = 1)

Contrastive divergence loss.
`vd` is a data sample, and `vm` are samples from the model.
"""
function contrastive_divergence(
    rbm::RBM, vd::AbstractTensor, vm::AbstractTensor; wd = nothing, wm = nothing
)
    Fd = mean_free_energy(rbm, vd; wts=wd)::Number
    Fm = mean_free_energy(rbm, vm; wts=wm)::Number
    return Fd - Fm
end

function mean_free_energy(
    rbm::RBM{<:AbstractLayer{N}}, v::AbstractTensor{N}; wts::Nothing = nothing
) where {N}
    check_size(rbm.visible, v)
    return free_energy(rbm, v)::Number
end

function mean_free_energy(rbm::RBM, v::AbstractArray; wts = nothing)
    @assert size(rbm.visible) == size(v)[1:ndims(rbm.visible)]
    F = free_energy(rbm, v)
    @assert size(F) == batchsize(rbm.visible, v)
    return wmean(F; wts)
end

function ∂contrastive_divergence(
    rbm::RBM, vd::AbstractTensor, vm::AbstractTensor;
    wd = nothing, wm = nothing, ts
)
    ∂d = ∂free_energy(rbm, vd; wts = wd, ts)
    ∂m = ∂free_energy(rbm, vm; wts = wm)
    return subtract_gradients(∂d, ∂m)
end

subtract_gradients(∂1::NamedTuple, ∂2::NamedTuple) = map(subtract_gradients, ∂1, ∂2)
subtract_gradients(∂1::AbstractTensor{N}, ∂2::AbstractTensor{N}) where {N} = ∂1 - ∂2

# update! mimics Flux.update!
function update!(optimizer, rbm::RBM, ∂::NamedTuple)
    update!(optimizer, rbm.w, ∂.w)
    update!(optimizer, rbm.visible, ∂.visible)
    update!(optimizer, rbm.hidden, ∂.hidden)
end

function update!(optimizer, layer::AbstractLayer, ∂::NamedTuple)
    for (k, g) in pairs(∂)
        Flux.update!(optimizer, getproperty(layer, k), g)
    end
end

function update!(optimizer, x::AbstractArray, ∂::AbstractArray)
    Flux.update!(optimizer, x, ∂)
end
