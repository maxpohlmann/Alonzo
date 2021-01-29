defmodule Typer do
  import Utils

  def free_tvars({:tvar, tvar}), do: [tvar]
  def free_tvars({:func, l, r}), do: free_tvars(l) ++ free_tvars(r)

  def sub_in_type(alpha={:tvar, tvar}, sub), do: Map.get(sub, tvar) || alpha
  def sub_in_type({:func, l, r}, sub), do: {:func, sub_in_type(l, sub), sub_in_type(r, sub)}

  def compose_subs(sub1, sub2) do
    sub2
      |> Enum.map(fn {alpha, tau} -> {alpha, sub_in_type(tau, sub1)} end)
      |> Map.new
      |> Map.merge(sub1)
  end

  def unify_types({:tvar, tvar}, tau) do
    cond do
      not Enum.member?(free_tvars(tau), tvar) ->
        %{tvar => tau}
      tvar == tau ->
        %{}
      true ->
        :fail
    end
  end
  def unify_types({:func, sigma1, sigma2}, {:tvar, tvar}) do
    unify_types({:tvar, tvar}, {:func, sigma1, sigma2})
  end
  def unify_types({:func, sigma1, sigma2}, {:func, tau1, tau2}) do
    u2 = unify_types(sigma2, tau2)
    if u2 != :fail do
      sigma1_sub = sub_in_type(sigma1, u2)
      tau1_sub = sub_in_type(tau1, u2)
      u1 = unify_types(sigma1_sub, tau1_sub)
      if u1 != :fail, do: compose_subs(u1, u2), else: :fail
    else
      :fail
    end
  end

  def unify_equations(eqset) do
    bigeq = Enum.reduce(eqset, fn(eq, acc) -> %{l: {:func, eq.l, acc.l}, r: {:func, eq.r, acc.r}} end)
    unify_types(bigeq.l, bigeq.r)
  end

  def eqset_E(basis, term, type, fresh \\ 0) do
    {eqset, _fresh} = eqset_E_inner(basis, term, type, fresh)
    eqset
  end
  def eqset_E_inner(basis, term, type, fresh) do
    case term do
      {:var, var} ->
        {[%{l: type, r: Map.get(basis, var)}], fresh}
      {:app, l, r} ->
        alpha = {:tvar, fresh}
        fresh = fresh + 1
        {e1, fresh} = eqset_E_inner(basis, l, {:func, alpha, type}, fresh)
        {e2, fresh} = eqset_E_inner(basis, r, alpha, fresh)
        {e1 ++ e2, fresh}
      {:abs, v, t} ->
        alpha = {:tvar, fresh}
        beta = {:tvar, fresh + 1}
        fresh = fresh + 2
        new_basis = Map.merge(basis, %{v => alpha})
        {e1, fresh} = eqset_E_inner(new_basis, t, beta, fresh)
        e2 = [%{l: {:func, alpha, beta}, r: type}]
        {e1 ++ e2, fresh}
    end
  end

  def pp(term) do
    basis = (fv=get_FV(term))
      |> Enum.with_index
      |> Enum.map(fn {var, i} -> {var, {:tvar, i+1}} end)
      |> Map.new
    fresh = length(fv) + 1
    eqset = eqset_E(basis, term, {:tvar, 0}, fresh)
    u = unify_equations(eqset)
    if u != :fail do
      basis = basis
        |> Enum.map(fn {var, t} -> {var, sub_in_type(t, u)} end)
        |> Map.new
      final_type = sub_in_type({:tvar, 0}, u)
      {basis, final_type}
    else
      {%{}, :fail}
    end
  end

  def pretty_tvars(_basis, :fail), do: {%{}, :fail}
  def pretty_tvars(basis, type) do
    tvars = basis
      |> Map.values
      |> Enum.map(&free_tvars/1)
      |> (&([free_tvars(type)] ++ &1)).()
      |> List.flatten
      |> Enum.uniq
    pretty = ["α", "β", "γ", "δ", "ϵ", "ζ", "η"]
    map = tvars
      |> Enum.with_index
      |> Enum.map(fn {tvar, i} -> {tvar, {:tvar, (if length(tvars) <= length(pretty), do: Enum.at(pretty, i), else: "α#{i}")}} end)
      |> Map.new

    basis = basis
      |> Enum.map(fn {var, t} -> {var, sub_in_type(t, map)} end)
      |> Map.new

    type = sub_in_type(type, map)

    {basis, type}
  end

  def show_type({:func, sigma, tau}), do: "(#{show_type(sigma)} → #{show_type(tau)})"
  def show_type({:tvar, tvar}), do: "#{tvar}"
  def show_type(:fail), do: "untypable"

  def show_basis(basis) do
    basis
      |> Enum.map(fn {var, t} -> "#{var}:#{show_type(t)}" end)
      |> Enum.join(", ")
  end


end
