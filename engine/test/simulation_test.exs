defmodule Engine.SimulationTest do
  use ExUnit.Case

  test "space needs a check and reaches a landing report" do
    state = Engine.new(:space, 42)
    assert {:error, :check_required} = Engine.step(state, :launch, 1)
    commands = [:check, :launch] ++ List.duplicate(:wait, 300)
    {:ok, checked, _} = Engine.replay(:space, 42, [:check, :launch])
    assert Engine.observe(checked).phase == :powered

    result =
      Enum.reduce_while(commands, {:ok, state, []}, fn command, {:ok, current, events} ->
        case Engine.step(current, command, 1) do
          {:ok, next, fresh} ->
            if next.status == :active,
              do: {:cont, {:ok, next, events ++ fresh}},
              else: {:halt, {:ok, next, events ++ fresh}}
        end
      end)

    {:ok, landed, events} = result
    assert landed.phase == :landed
    assert Enum.any?(events, &(&1.type == :landed))
    assert landed.peak_altitude_m > 0
  end

  test "same seed and commands reproduce state, events and observations" do
    commands = [:check, :launch] ++ List.duplicate(:wait, 30)
    assert Engine.replay(:space, 123, commands) == Engine.replay(:space, 123, commands)
    {:ok, first, _} = Engine.replay(:space, 123, commands)
    {:ok, second, _} = Engine.replay(:space, 124, commands)
    refute first.observed_altitude_m == second.observed_altitude_m
  end

  test "central resolves both incidents with two teams" do
    commands = [{:assign, :orion}, {:assign, :vega}] ++ List.duplicate(:wait, 5)
    {:ok, state, events} = Engine.replay(:central, 42, commands)
    assert state.status == :success
    assert state.available_teams == 2
    assert Enum.count(events, &(&1.type == :contact_resolved)) == 2
  end

  test "central misses deadlines without assignments" do
    {:ok, state, events} = Engine.replay(:central, 42, List.duplicate(:wait, 18))
    assert state.status == :partial
    assert Enum.count(events, &(&1.type == :deadline_missed)) == 2
  end

  test "calculations validate units and inputs" do
    assert Engine.Calculator.evaluate(:average_speed, %{distance_m: 100, time_s: 20}).value == 5.0
    assert Engine.Calculator.evaluate(:work_eta, %{remaining_work: 5, teams: 2}).value == 3

    assert {:error, :invalid_inputs_or_model} =
             Engine.Calculator.evaluate(:average_speed, %{distance_m: 10, time_s: 0})
  end
end
