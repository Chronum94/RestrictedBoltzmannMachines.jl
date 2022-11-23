# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- This CHANGELOG file.
- Rescale weights to norm 1, instead of hidden unit activities to unit variances (https://github.com/cossio/RestrictedBoltzmannMachines.jl/commit/4cae554013d7b6ab97a900910ff67d2a43d263b0). This is a simpler way to settle the scale degeneracy between weights and hidden unit activities for continuous hidden units.
    * Introduce `rescale_weights!(rbm)` to normalize weights attached to each hidden units.
    * Now `pcd!(...; rescale=true, ...)` uses `rescale_weights!`, instead of scaling hidden unit activities to unit variances.
    * BREAKING: Removed `ρh`, `ϵh` keyword arguments from `pcd!`, which used to control the tracking of hidden unit variances during training.
    * BREAKING: `grad2var` has been removed.
- Allow passing `ps`, `state` to `pcd!` to control which parameters are optimized. Now `pcd!` returns `state, ps`, which can be breaking. (https://github.com/cossio/RestrictedBoltzmannMachines.jl/commit/05fade7e567f557dba457c287ca4ebf0faab14d4).

## [v1.0.0]

- Release v1.0.0 (https://github.com/cossio/RestrictedBoltzmannMachines.jl/commit/9eeb7cf313362258d2cb8a83f725c382049a9d44).