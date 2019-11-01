__precompile__()
module ArviZ

using Base: @__doc__
using Reexport
using PyCall
@reexport using PyPlot
using Pandas: DataFrame, Series
using MCMCChains: AbstractChains

import Base: convert, propertynames, getproperty, hash, show, summary, +
import Base.Docs: getdoc
import PyCall: PyObject

# Exports

## Plots
export plot_autocorr,
       plot_compare,
       plot_density,
       plot_dist,
       plot_elpd,
       plot_energy,
       plot_ess,
       plot_forest,
       plot_hpd,
       plot_joint,
       plot_kde,
       plot_khat,
       plot_loo_pit,
       plot_mcse,
       plot_pair,
       plot_parallel,
       plot_posterior,
       plot_ppc,
       plot_rank,
       plot_trace,
       plot_violin

## Stats
export compare, hpd, loo, loo_pit, psislw, r2_score, waic

## Diagnostics
export bfmi, geweke, ess, rhat, mcse

## Stats utils
export autocov, autocorr, make_ufunc, wrap_xarray_ufunc

## Data
export InferenceData,
       convert_to_inference_data,
       load_arviz_data,
       to_netcdf,
       from_netcdf,
       from_dict,
       from_mcmcchains,
       concat,
       concat!

## Utils
export interactive_backend

## rcParams
export rc_context

const arviz = PyNULL()

function __init__()
    copy!(arviz, pyimport_conda("arviz", "arviz", "conda-forge"))

    pytype_mapping(arviz.InferenceData, InferenceData)
end

include("utils.jl")
include("data.jl")
include("diagnostics.jl")
include("plots.jl")
include("stats.jl")
include("stats_utils.jl")
include("mcmcchains.jl")

end # module
