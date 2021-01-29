defmodule Parser do
  import Utils
  import Reducer

  def parse(inp, metavars \\ %{}) do
    {term, inp} = parse_term(to_charlist(inp))

    if length(inp) != 0, do: raise "closing parenthesis without opening: #{inp}"

    term = replace_metavars(term, metavars)

    if (b = check_bindings(term)) != :ok do
      IO.puts show(term)
      raise "Variable #{b} is bound more than once."
    end

    term
  end


  def parse_term(inp, prev_term \\ nil) do
    cond do
      inp == '' ->
        {prev_term, ''}

      [hd inp] == ')' ->
        if prev_term == nil, do: raise "Empty parentheses before: #{inp}"
        {prev_term, inp}

      [hd inp] == ' ' ->
        parse_term((tl(inp)), prev_term)

      true ->
        {term, inp} = cond do
          [hd inp] == '(' ->
            {term, inp} = parse_term((tl(inp)), nil)
            if (inp == '') or ([hd inp] != ')'), do: raise "expected closing parenthesis before: #{inp}"
            {term, tl(inp)}

          String.match?((to_string [hd inp]), ~r/^[a-z]$/) ->
            {_term, _inp} = parse_var(inp)

          String.match?((to_string [hd inp]), ~r/^[A-Z0-9:]$/) ->
            {_term, _inp} = parse_meta(inp)

          [hd inp] in ['\\', 'λ', '&'] ->
            {_term, _inp} = parse_abs(tl(inp))

          true ->
            raise "Unexpected character at: #{inp}"
        end

        new_term = if prev_term == nil, do: term, else: {:app, prev_term, term}
        parse_term(inp, new_term)
    end
  end


  def parse_var(inp, var \\ []) do
    # function is only called when inp[0] matches [a-z] therefore var will contain at least a letter
    # note that this regex allows _ and ' to occur *after* the first character
    cond do
      inp != [] and String.match?((to_string [hd inp]), ~r/^[a-z0-9_']$/i) ->
        parse_var((tl(inp)), (var ++ [hd inp]))

      true ->
        {{:var, (to_string(var))}, inp}
    end
  end


  def parse_meta(inp, var \\ []) do
    # identical to parse_var&2, but for inp[0] matches [A-Z0-9]
    cond do
      inp != [] and String.match?((to_string [hd inp]), ~r/^[a-z0-9:_']$/i) ->
        parse_meta((tl(inp)), (var ++ [hd inp]))

      true ->
        v = to_string(var)
        int_parse = Integer.parse(v)
        case int_parse do
          {int, ""} ->
            {{:num, int}, inp}
          _ ->
            {{:meta, v}, inp}
        end
    end
  end


  def parse_abs(inp, bound \\ false) do
    cond do
      inp == '' ->
        raise "Unfinished abstraction."

      [hd inp] == ' ' ->
        parse_abs((tl(inp)), bound)

      [hd inp] == '.' ->
        {term, inp} = parse_term(tl(inp))
        if not bound, do: raise "No vars bound before: #{inp}"
        {term, inp}

      String.match?((to_string [hd inp]), ~r/^[a-z#]$/) ->
        {{:var, var}, inp} = parse_var(inp)
        {term, inp} = parse_abs(inp, true)
        {{:abs, var, term}, inp}

      true ->
        raise "Unexpected character at: #{inp}"
    end
  end


  def church_numeral(int, term \\ nil) do
    term = term || {:var, "x"}
    if int == 0 do
      {:abs, "f", {:abs, "x", term}}
    else
      term = {:app, {:var, "f"}, term}
      church_numeral(int-1, term)
    end
  end


  def replace_metavars(term, metavars, bvs \\ []) do
    case term do
      {:var, v} ->
        {:var, v}

      {:app, l, r} ->
        {:app, replace_metavars(l, metavars, bvs), replace_metavars(r, metavars, bvs)}

      {:abs, v, t} ->
        {:abs, v, replace_metavars(t, metavars, bvs ++ [v])}

      {:num, int} ->
        alpha_convert_term(church_numeral(int), bvs, bvs)

      {:meta, v} ->
        if (t = metavars[v]) != nil do
          alpha_convert_term(t, bvs, bvs)
        else
          raise "Unknown metavariable #{v}"
        end
    end
  end

end
