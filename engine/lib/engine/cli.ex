defmodule Engine.CLI do
  @moduledoc "Minimal text terminal for exercising both introductory missions."

  def main(args) do
    case args do
      [mode] when mode in ["space", "central"] ->
        state = Engine.new(String.to_existing_atom(mode), 42)
        IO.puts("TERMINAL LAUNCH SIM — #{mode} — modelo #{Engine.model_version()}")
        IO.puts(help(mode))
        loop(state)

      _ ->
        IO.puts("Uso: mix run -e 'Engine.CLI.main(System.argv())' -- space|central")
    end
  end

  defp loop(state) do
    IO.inspect(Engine.observe(state), label: "Instrumentos")

    if state.status == :active do
      case IO.gets("> ") do
        nil ->
          :ok

        line ->
          command = String.trim(line)

          cond do
            command == "quit" ->
              :ok

            command == "help" ->
              IO.puts(help(Atom.to_string(state.mode)))
              loop(state)

            true ->
              case parse(command, state.mode) do
                {:wait, count} ->
                  advance(state, :wait, count)

                {:ok, parsed} ->
                  advance(state, parsed, 1)

                :error ->
                  IO.puts("Comando inválido. Digite help.")
                  loop(state)
              end
          end
      end
    else
      IO.puts("Relatório: #{state.status}; #{length(state.log)} evento(s).")
      Enum.each(state.log, &IO.inspect/1)
    end
  end

  defp advance(state, command, count) do
    result =
      Enum.reduce_while(1..count, {:ok, state}, fn _, {:ok, current} ->
        case Engine.step(current, command, 1) do
          {:ok, next, events} ->
            Enum.each(events, &IO.inspect(&1, label: "Evento"))
            if next.status == :active, do: {:cont, {:ok, next}}, else: {:halt, {:ok, next}}

          {:error, reason} ->
            {:halt, {:error, reason, current}}
        end
      end)

    case result do
      {:ok, next} ->
        loop(next)

      {:error, reason, current} ->
        IO.puts("Rejeitado: #{reason}")
        loop(current)
    end
  end

  defp parse("check", :space), do: {:ok, :check}
  defp parse("launch", :space), do: {:ok, :launch}
  defp parse("abort", :space), do: {:ok, :abort}
  defp parse("wait", _), do: {:ok, :wait}

  defp parse("wait " <> count, _) do
    case Integer.parse(count) do
      {n, ""} when n in 1..500 -> {:wait, n}
      _ -> :error
    end
  end

  defp parse("assign orion", :central), do: {:ok, {:assign, :orion}}
  defp parse("assign vega", :central), do: {:ok, {:assign, :vega}}
  defp parse("recall orion", :central), do: {:ok, {:recall, :orion}}
  defp parse("recall vega", :central), do: {:ok, {:recall, :vega}}
  defp parse(_, _), do: :error

  defp help("space"), do: "check, launch, wait [1..500], abort, help, quit"
  defp help("central"), do: "assign orion|vega, recall orion|vega, wait [1..500], help, quit"
end
