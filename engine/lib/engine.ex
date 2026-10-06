defmodule Engine do
  @moduledoc "Pure deterministic engine for introductory missions."

  @version "0.2.0"
  def model_version, do: @version

  def new(mode, seed, tech_level \\ 0)

  def new(mode, seed, tech_level)
      when mode in [:space, :central] and is_integer(seed) and seed >= 0 and
             tech_level in [0, 1] do
    base = %{
      mode: mode,
      model_version: @version,
      seed: seed,
      tech_level: tech_level,
      rng: rem(seed, 4_294_967_296),
      tick: 0,
      time_s: 0,
      status: :active,
      log: []
    }

    module(mode).new(base)
  end

  def new(_, _, _), do: {:error, :invalid_mode_seed_or_technology}

  @doc "Apply one command and advance exactly one simulated second."
  def step(%{status: :active, mode: mode} = state, command, 1) when mode in [:space, :central] do
    with {:ok, commanded, command_events} <- module(mode).command(state, command) do
      {advanced, tick_events} = module(mode).tick(commanded)
      events = Enum.map(command_events ++ tick_events, &Map.put(&1, :time_s, state.time_s + 1))

      {:ok,
       %{advanced | tick: state.tick + 1, time_s: state.time_s + 1, log: state.log ++ events},
       events}
    end
  end

  def step(%{status: status}, _, _) when status != :active, do: {:error, :run_finished}
  def step(_, _, _), do: {:error, :invalid_step}

  def observe(%{mode: mode} = state), do: module(mode).observe(state)

  def replay(mode, seed, commands, tech_level \\ 0) when is_list(commands) do
    case new(mode, seed, tech_level) do
      state when is_map(state) ->
        Enum.reduce_while(commands, {:ok, state, []}, fn command, {:ok, current, events} ->
          case step(current, command, 1) do
            {:ok, next, fresh} -> {:cont, {:ok, next, events ++ fresh}}
            error -> {:halt, error}
          end
        end)

      error ->
        error
    end
  end

  @doc "Explicit seeded LCG; no process or system random state is consulted."
  def random(%{rng: rng} = state) do
    next = rem(1_664_525 * rng + 1_013_904_223, 4_294_967_296)
    {%{state | rng: next}, next / 4_294_967_296}
  end

  defp module(:space), do: Engine.Space
  defp module(:central), do: Engine.Central
end
