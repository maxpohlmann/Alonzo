defmodule Reducer do
  import Utils

  def alpha_convert_redex({:app, {:abs, bvar, aterm}, arg}) do
    vs_arg = get_V arg
    vs_aterm = get_V aterm
    vs_in_use = (vs_aterm ++ [bvar] ++ vs_arg) |> Enum.uniq

    bvs_aterm = get_BV aterm
    if length(vs_arg) == length(vs_arg -- bvs_aterm) do
      {_required=false, {:app, {:abs, bvar, aterm}, arg}}
    else
      new_aterm = alpha_convert_term(aterm, vs_arg, vs_in_use)
      {_required=true, {:app, {:abs, bvar, new_aterm}, arg}}
    end
  end


  def alpha_convert_term(term, vs_to_rename, vs_in_use) do
    case term do
      {:abs, v, t} ->
        if Enum.member?(vs_to_rename, v) do
          new_v = find_new_v(v, vs_in_use)
          vs_in_use = vs_in_use ++ [new_v]
          new_t = substitute(t, v, {:var, new_v})
          {:abs, new_v, alpha_convert_term(new_t, vs_to_rename, vs_in_use)}
        else
          {:abs, v, alpha_convert_term(t, vs_to_rename, vs_in_use)}
        end

      {:app, l, r} ->
        new_l = alpha_convert_term(l, vs_to_rename, vs_in_use)
        new_r = alpha_convert_term(r, vs_to_rename, vs_in_use)
        {:app, new_l, new_r}

      {:var, v} ->
        {:var, v}
    end
  end

  def find_new_v(v, vs_in_use) do
    new_v = v <> "'"
    if Enum.member?(vs_in_use, new_v), do: find_new_v(new_v, vs_in_use), else: new_v
  end


  def substitute(term, var, sub) do
    case term do
      {:abs, v, t} ->
        if v == var, do: raise "Replacing #{var} in abstraction for the same var? Shouldn't happen."
        new_t = substitute(t, var, sub)
        {:abs, v, new_t}

      {:app, l, r} ->
        new_l = substitute(l, var, sub)
        new_r = substitute(r, var, sub)
        {:app, new_l, new_r}

      {:var, ^var} ->
        sub

      {:var, v} ->
        {:var, v}
    end
  end


  def beta_step(term) do
    beta = beta_step_inner(term)
    if beta == :no do
      {nil, nil}
    else
      {alpha_required?, alpha, reduct} = beta
      if alpha_required?, do: {alpha, reduct}, else: {nil, reduct}
    end
  end
  def beta_step_inner(term, depth \\ 0) do
    if depth > 1000, do: raise "Leftmost redex has abstraction/application depth > 1000, limit reached."
    case term do
      {:app, {:abs, _bvar, _aterm}, _arg} = redex ->
        {alpha_required?, alpha={:app, {:abs, bvar, aterm}, arg}} = alpha_convert_redex(redex)
        reduct = substitute(aterm, bvar, arg)
        {alpha_required?, alpha, reduct}

      {:app, l, r} ->
        cond do
          (beta_l = beta_step_inner(l, depth+1)) != :no ->
            {alpha_required?, alpha, reduct} = beta_l
            {alpha_required?, {:app, alpha, r}, {:app, reduct, r}}
          (beta_r = beta_step_inner(r, depth+1)) != :no ->
            {alpha_required?, alpha, reduct} = beta_r
            {alpha_required?, {:app, l, alpha}, {:app, l, reduct}}
          true ->
            :no
        end

      {:abs, v, t} ->
        cond do
          (beta_t = beta_step_inner(t, depth+1)) != :no ->
            {alpha_required?, alpha, reduct} = beta_t
            {alpha_required?, {:abs, v, alpha}, {:abs, v, reduct}}
          true ->
            :no
        end

      {:var, _v} ->
        :no
    end
  end


  def full_beta_reduction(term, silent \\ true, term_db \\ nil, n_steps \\ 5000) do
    if n_steps == 0, do: raise "No β-nf found after 5000 steps, limit reached."

    {alpha, reduct} = beta_step(term)
    if alpha != nil do
      outp = show(alpha)
      if not silent, do: IO.puts("α> #{outp}")
    end

    if reduct != nil do
      outp = show(reduct)
      if not silent, do: IO.puts("β> #{outp}")

      term_db = term_db || debruijn(term)
      redcuct_db = debruijn(reduct)
      if term_db == redcuct_db do
        if not silent, do: IO.puts("Term has no β-nf.")
        term
      else
        full_beta_reduction(reduct, silent, redcuct_db, n_steps-1)
      end
    else
      if silent do
        # in silent mode, still show the last step
        outp = show(term)
        IO.puts("β> #{outp}")
      end
      term
    end
  end

end
