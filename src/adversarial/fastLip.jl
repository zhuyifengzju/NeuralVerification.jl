struct FastLip
    maxIter::Int64
    ϵ0::Float64
    accuracy::Float64
end
# since FastLip is "higher" on the hierarchy, it defines both:
convert(::Type{FastLin}, S::FastLip) = FastLin(S.maxIter, S.ϵ0, S.accuracy)
convert(::Type{FastLip}, S::FastLin) = FastLip(S.maxIter, S.ϵ0, S.accuracy)

FastLin(S::FastLip) = FastLin(S.maxIter, S.ϵ0, S.accuracy)

function solve(solver::FastLip, problem::Problem)
	c, d = tosimplehrep(problem.output)
	y = compute_output(problem.network, problem.input.center)
	J = (c * y - d)[1]
	if J > 0
		return AdversarialResult(:UNSAT, -J)
	end
	result = solve(FastLin(solver), problem)
	result.status || return result
	ϵ_fastLin = result.max_disturbance
	LG, UG = get_gradient(problem.network, problem.input)

	# C = problem.network.layers[1].weights
	# L = zeros(size(C))
	# U = zeros(size(C))
	# for l in 2:length(problem.network.layers)
	# 	C, L, U = bound_layer_grad(C, L, U, problem.network.layers[l].weights, act_pattern[l])
	# end
	# v = max.(abs.(C+L), abs.(C+U))

	a, b = interval_map(c, LG, UG)
	v = max.(abs.(a), abs.(b))
	ϵ = min(-J/sum(v), ϵ_fastLin)

    if ϵ > minimum(problem.input.radius)
        return AdversarialResult(:SAT, ϵ)
    else
        return AdversarialResult(:UNSAT, ϵ)
    end
end

function bound_layer_grad(C::Matrix, L::Matrix, U::Matrix, W::Matrix, D::Vector{Float64})
	n_input = size(C)
	rows, cols = size(W)
	new_C = zeros(rows, n_input)
	new_L = zeros(rows, n_input)
	new_U = zeros(rows, n_input)
	for k in 1:n_input         # NOTE n_input is 2-D
		for j in 1:rows, i in 1:cols

            u = U[i, k]
            l = L[i, k]
            c = C[i, k]
            w = W[j, i]

            if D[i] == 1

                new_C[j,k] += w*c
                new_U[j,k] += (w > 0) ? u : l
                new_L[j,k] += (w > 0) ? l : u

            elseif D[i] == 0 && w*(c+u)>0

                new_U[j,k] += w*(c+u)
                new_L[j,k] += w*(c+l)

            end
		end
	end
	return (new_C, new_L, new_U)
end

