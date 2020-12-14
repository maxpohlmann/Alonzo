defmodule CLI do
  import Parser
  import Utils
  import Reducer

  def main(args) do
    metavar_file = if args == [], do: "metavars.txt", else: Enum.at(args, 0)

    metavars = case File.read(metavar_file) do
      {:ok, txt} ->
        load_metavars(String.split(txt, "\n"))
      {:error, _} ->
        if args != [], do: IO.puts("Coulnd't read #{metavar_file}")
        %{}
    end
    metavars_db = metavars
      |> Enum.map(fn {mv, term} -> {debruijn(term), mv} end)
      |> Enum.into(%{})

    repl_loop(metavars, metavars_db)
  end


  def repl_loop(metavars, metavars_db) do
    inp = IO.gets("λ$ ")
    if inp == :eof do
      safe_quit(metavars)
    else
      inp = inp |> String.trim

      {metavars, metavars_db} = if inp != "" do
        try do
          cond do
            String.starts_with?(inp, "!") ->
              handle_mv_decl(inp, metavars, metavars_db)
            String.starts_with?(inp, ";") ->
              handle_normal_input(inp |> String.split_at(1) |> elem(1), metavars, metavars_db, true)
            true ->
              handle_normal_input(inp, metavars, metavars_db, false)
          end
        rescue
          e in RuntimeError ->
            IO.puts(e.message)
            # reraise(e, __STACKTRACE__)

          {metavars, metavars_db}
        end
      end

      repl_loop(metavars, metavars_db)
    end
  end


  def handle_mv_decl(inp, metavars, metavars_db, silent \\ false) do
    inp = inp |> String.trim_leading("!") |> String.trim |> to_charlist
    if inp != [] do
      if not String.match?((to_string [hd inp]), ~r/^[A-Z:]$/), do: raise "Expecting metavariable declaration."
      {{:meta, mv}, inp} = parse_meta(inp)
      inp = inp |> to_string |> String.trim |> to_charlist
      if inp == [] or [hd(inp)] != '=', do: raise "Expected \"=\"."
      inp = inp |> tl |> to_string
      if inp == "", do: raise "Expecting definition for metavariable."
      term = parse(inp, metavars)

      outp = show(term)
      if not silent, do: IO.puts("λ> #{mv} ≡ #{outp}")

      if not silent and (get_FV(term) != []), do: IO.puts("Warning: Metavariable definitions probably shouldn't contain free variables.")

      term_db = debruijn(term)
      {Map.put(metavars, mv, term), Map.put(metavars_db, term_db, mv)}
    else
      {metavars, metavars_db}
    end
  end


  def handle_normal_input(inp, metavars, metavars_db, silent) do
    term = parse(inp, metavars)

    outp = show(term)
    IO.puts("λ> #{outp}")

    reduct = full_beta_reduction(term, silent)

    redcuct_with_mv = include_metavars(reduct, metavars_db)

    if redcuct_with_mv != reduct do
      outp = show(redcuct_with_mv)
      IO.puts("≡  #{outp}")
    end

    {metavars, metavars_db}
  end


  def load_metavars(lines, metavars \\ %{}, metavars_db \\ %{}) do
    if lines == [] do
      metavars
    else
      line = String.trim(hd(lines))
      {metavars, metavars_db} = try do
        handle_mv_decl(line, metavars, metavars_db, true)
      rescue
        e in RuntimeError -> IO.puts("Error while parsing \"#{line}\": " <> e.message)

        {metavars, metavars_db}
      end
      load_metavars(tl(lines), metavars, metavars_db)
    end
  end


  def safe_quit(metavars) do
    txt = for {mv, term} <- metavars, do: "#{mv} = #{show(term)}\n"
    File.write!("metavars.txt", txt)
    IO.puts("Saved metavariables to metavars.txt.")
  end

end
