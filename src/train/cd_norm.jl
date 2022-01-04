"""
    train_norm!(rbm, data)

Trains the RBM on data, using the weight normalization heuristic.
See Salimans & Kingma 2016,
https://proceedings.neurips.cc/paper/2016/hash/ed265bc903a5a097f61d3ec064d96d2e-Abstract.html.
"""
function train_norm!(rbm::RBM, data::AbstractArray;
    batchsize = 1,
    epochs = 1,
    optimizer = Flux.ADAM(), # optimizer algorithm
    history::MVHistory = MVHistory(), # stores training log
    lossadd = (_...) -> 0, # regularization
    verbose::Bool = true,
    weights::AbstractVector = FillArrays.Trues(_nobs(data)), # data point weights
    steps::Int = 1, # Monte Carlo steps to update fantasy particles
)
    @assert size(data) == (size(rbm.visible)..., size(data)[end])
    @assert _nobs(data) == _nobs(weights)

    ps = Flux.params(rbm)
    # v, g notation from Salimans & Kingma 2016
    weights_g = sqrt.(sum(abs2, rbm.weights; dims=layerdims(rbm.visible)))
    weights_v = rbm.weights ./ weights_g
    ps = Flux.params(ps..., weights_g, weights_v)

    # initialize fantasy chains
    _idx = rand(1:_nobs(data), batchsize)
    _vm = selectdim(data, ndims(data), _idx)
    vm = sample_v_from_v(rbm, _vm; steps = steps)

    for epoch in 1:epochs
        batches = minibatches(data, weights; batchsize = batchsize)
        Δt = @elapsed for (b, (vd, wd)) in enumerate(batches)
            # update fantasy chains
            vm = sample_v_from_v(rbm, vm; steps = steps)

            # compute contrastive divergence gradient
            gs = Zygote.gradient(ps) do
                norm_v = sqrt.(sum(abs2, weights_v; dims=layerdims(rbm.visible)))
                rbm_ = RBM(rbm.visible, rbm.hidden, weights_g .* weights_v ./ norm_v)
                loss = contrastive_divergence(rbm_, vd, vm, wd)
                regu = lossadd(rbm_, vd, vm, wd)
                ChainRulesCore.ignore_derivatives() do
                    push!(history, :cd_loss, loss)
                    push!(history, :reg_loss, regu)
                end
                return loss + regu
            end

            gs_0 = Zygote.gradient(ps) do
                contrastive_divergence(rbm, vd, vm, wd)
            end

            norm_v = reshape(sqrt.(sum(abs2, weights_v; dims=layerdims(rbm.visible))), 1, length(rbm.hidden))
            ∂g = reshape(gs[weights_g], 1, length(rbm.hidden))
            ∂v = reshape(gs[weights_v], length(rbm.visible), length(rbm.hidden))
            ∂w = reshape(gs_0[rbm.weights], length(rbm.visible), length(rbm.hidden))
            v_mat = reshape(weights_v, length(rbm.visible), length(rbm.hidden))
            g_vec = reshape(weights_g, 1, length(rbm.hidden))
            @assert ∂g ≈ sum(v_mat .* ∂w ./ norm_v; dims=1)
            @assert ∂v ≈ g_vec .* ∂w ./ norm_v - g_vec .* ∂g .* v_mat ./ norm_v.^2

            # update parameters using gradient
            Flux.update!(optimizer, ps, gs)

            # update RBM weights
            norm_v = sqrt.(sum(abs2, weights_v; dims=layerdims(rbm.visible)))
            rbm.weights .= weights_g .* weights_v ./ norm_v

            push!(history, :epoch, epoch)
            push!(history, :batch, b)
        end

        lpl = weighted_mean(log_pseudolikelihood(rbm, data), weights)
        push!(history, :lpl, lpl)
        if verbose
            Δt_ = round(Δt, digits=2)
            lpl_ = round(lpl, digits=2)
            println("epoch $epoch/$epochs ($(Δt_)s), log(pseudolikelihood)=$lpl_")
        end
    end
    return history
end