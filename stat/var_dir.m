function V = var_dir(alpha)
	% V = var_dir(alpha)
	%
	% Variance of a Dirichlet prior
	d = ndims(alpha);
	K = size(alpha, d);
	alpha0 = sum(alpha, d);
	Alpha0 = alpha0.^2 .* (alpha0 - 1);
	V = bsxfun(@times, alpha ./ Alpha0, bsxfun(@minus, alpha0, alpha));
