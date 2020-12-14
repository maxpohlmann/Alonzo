defmodule Utils do

  def collect_nested_bindings(term, vars \\ []) do
    case term do
      {:abs, v, t} ->
        collect_nested_bindings(t, vars ++ [v])
      _ ->
        {vars, term}
    end
  end


  def show(term, merge_lambdas \\ true) do
    case term do
      {:var, v} ->
        v
      {:app, l, r} ->
        "(#{show(l, merge_lambdas)} #{show(r, merge_lambdas)})"
      {:abs, v, t} = term ->
        if merge_lambdas do
          {vs, tt} = collect_nested_bindings(term)
          "(λ#{Enum.join(vs, " ")}.#{show(tt, merge_lambdas)})"
        else
          "(λ#{v}.#{show(t)})"
        end
      {:meta, v} ->
        v
      {:num, int} ->
        "#{int}"
    end
  end


  def dump(term, depth \\ 0) do
    output = case term do
      {:var, v} ->
        v
      {:app, l, r} ->
        ":app: \n#{dump(l, depth + 1)}\n#{dump(r, depth + 1)}"
        # ":app: (\n#{dump(l, depth + 1)}\n#{dump(r, depth + 1)}\n#{String.duplicate("  ", depth)})"
      {:abs, v, t} ->
        "λ#{v}.(\n#{dump(t, depth + 1)}\n#{String.duplicate("  ", depth)})"
    end
    String.duplicate("  ", depth) <> output
  end


  def get_FV(term) do
    case term do
      {:var, v} ->
        [v]
      {:app, l, r} ->
        get_FV(l) ++ get_FV(r)
      {:abs, v, t} ->
        get_FV(t) -- [v]
    end |> Enum.uniq
  end


  def get_BV(term) do
    case term do
      {:var, _v} ->
        []
      {:app, l, r} ->
        get_BV(l) ++ get_BV(r)
      {:abs, v, t} ->
        [v] ++ get_BV(t)
    end |> Enum.uniq
  end


  def get_V(term) do
    case term do
      {:var, v} ->
        [v]
      {:app, l, r} ->
        get_V(l) ++ get_V(r)
      {:abs, v, t} ->
        get_V(t) ++ [v]
    end |> Enum.uniq
  end


  def check_bindings(term, bvs \\ []) do
    case term do
      {:var, _v} ->
        :ok
      {:app, l, r} ->
        cond do
          (b = check_bindings(l, bvs)) != :ok ->
            b
          (b = check_bindings(r, bvs)) != :ok ->
            b
          true ->
            :ok
        end
      {:abs, v, t} ->
        if Enum.member?(bvs, v) do
          v
        else
          check_bindings(t, (bvs ++ [v]))
        end
      end
  end


  def debruijn(term, bindings \\ []) do
    case term do
      {:var, v} ->
        i = Enum.find_index(bindings, fn x -> x == v end)
        if i == nil, do: {:var, v}, else: {:var, "#{i}"}
      {:app, l, r} ->
        {:app, debruijn(l, bindings), debruijn(r, bindings)}
      {:abs, v, t} ->
        {:abs, "", debruijn(t, [v] ++ bindings)}
    end
  end


  def get_church_numeral(term_db) do
    case term_db do
      {:abs, "", {:abs, "", t}} ->
        get_church_numeral_inner(t)
      _ ->
        nil
    end
  end
  def get_church_numeral_inner(term_db, int \\ 0) do
    case term_db do
      {:var, "0"} ->
        int
      {:app, {:var, "1"}, r} ->
        get_church_numeral_inner(r, int+1)
      _ ->
        nil
    end
  end


  def include_metavars(term, metavars_db, term_db \\ nil) do
    term_db = term_db || debruijn(term)

    cond do
      (mv = metavars_db[term_db]) != nil ->
        {:meta, mv}
      (cn = get_church_numeral(term_db)) != nil ->
        {:num, cn}
      true ->
        case term do
          {:var, v} ->
            {:var, v}

          {:app, l, r} ->
            ldb = elem(term_db, 1)
            rdb = elem(term_db, 2)
            lm = include_metavars(l, metavars_db, ldb)
            rm = include_metavars(r, metavars_db, rdb)
            {:app, lm, rm}

          {:abs, v, t} ->
            tdb = elem(term_db, 2)
            tm = include_metavars(t, metavars_db, tdb)
            {:abs, v, tm}
        end
    end
  end

end
