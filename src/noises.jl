#  Copyright 2015, Vincent Leclere, Francois Pacaud and Henri Gerard
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.
#############################################################################
# Probability utilities:
# - implement a type to define discrete probability distributions
# - add functions to build scenarios with given probability laws
#############################################################################

using Iterators

type NoiseLaw
    # Number of points in distribution:
    supportSize::Int64
    # Position of points:
    support::Array{Float64,2}
    # Probabilities of points:
    proba::Vector{Float64}

    function NoiseLaw(supportSize, support, proba)
        supportSize = convert(Int64,supportSize)
        if ndims(support)==1
            support = reshape(support,1,length(support))
        end

        if ndims(proba) == 2
            proba = vec(proba)
        elseif  ndims(proba) >= 2
            proba = squeeze(proba,1)
        end

        return new(supportSize,support,proba)
    end
end


"""
Generic constructor to instantiate NoiseLaw


# Arguments
* `support`:
    Position of each point
* `proba`:
    Probabilities of each point

# Return
* `law::NoiseLaw`
"""
function NoiseLaw(support, proba)
    return NoiseLaw(length(proba), support, proba)
end


"""
Generate all permutations between discrete probabilities specified in args.

# Usage

```julia
julia> noiselaw_product(law1, law2, ..., law_n)

```
# Arguments
* `law::NoiseLaw`:
    First law to consider
* `laws::Tuple(NoiseLaw)`:
    Other noiselaws

# Return
`output::NoiseLaw`

# Exemple
    `noiselaw_product(law1, law2)`
with law1 : P(X=x_i) = pi1_i
and  law1 : P(X=y_i) = pi2_i
return the following discrete law:
    output: P(X = (x_i, y_i)) = pi1_i * pi2_i

"""
function noiselaw_product(law, laws...)
    if length(laws) == 1
        # Read first law stored in tuple laws:
        n2 = laws[1]
        # Get support size of these two laws:
        nw1 = law.supportSize
        nw2 = n2.supportSize
        # and dimensions of aleas:
        ndim1 = size(law.support)[1]
        ndim2 = size(n2.support)[1]

        # proba and support will defined the output discrete law
        proba = zeros(nw1*nw2)
        support = zeros(ndim1 + ndim2, nw1*nw2)

        count = 1
        # Use an iterator to find all permutations:
        for tup in product(1:nw1, 1:nw2)
            i, j = tup
            # P(X = (x_i, y_i)) = pi1_i * pi2_i
            proba[count] = law.proba[i] * n2.proba[j]
            support[:, count] = vcat(law.support[:, i], n2.support[:, j])
            count += 1
        end
        return NoiseLaw(support, proba)
    else
        # Otherwise, compute result with recursivity:
        return noiselaw_product(law, noiselaw_product(laws[1], laws[2:end]...))
    end
end


"""
Generate one sample of the aleas of the problem at time t

# Arguments
* `law::Vector{NoiseLaw}`:
    Vector of discrete independent random variables
* `t::Int`:
    time step at which a sample is needed

# Return
* `sample::Array(Float64, dimAlea}`:
    an Array of size dimAlea containing a sample w
"""
function sampling(law::Vector{NoiseLaw}, t::Int64)
    return law[t].support[:, rand(Categorical(law[t].proba))]
end


"""
Simulate n scenarios and return a 3D array

# Arguments
* `laws::Vector{NoiseLaw}`:
    Distribution laws corresponding to each timestep
* `n::Int64`:
    number of scenarios to simulate

# Return
* `scenarios::Array{Float64, 3}`:
    scenarios[t,k,:] is the noise at time t for scenario k
"""
function simulate_scenarios(laws::Vector{NoiseLaw}, n::Int64)
    T = length(laws)
    dimAlea = size(laws[1].support)[1]
    dims =(T,n,dimAlea)
    if typeof(laws) == Distributions.Normal
        scenarios = rand(laws, dims)
    else
        scenarios = zeros(dims)

        for k=1:dims[2]
            for t=1:dims[1]
                gen = Categorical(laws[t].proba)
                scenarios[t, k, :] = laws[t].support[:, rand(gen)]
            end

        end
    end

    return scenarios
end

