defmodule Engine.Calculator do
  @moduledoc "Unit-aware reference calculations for the introductory missions."

  def evaluate(:average_speed, %{distance_m: distance, time_s: time})
      when is_number(distance) and distance >= 0 and is_number(time) and time > 0 do
    %{
      value: distance / time,
      unit: "m/s",
      model_version: Engine.model_version(),
      explanation: "distance_m / time_s; average over the interval"
    }
  end

  def evaluate(:work_eta, %{remaining_work: work, teams: teams})
      when is_integer(work) and work >= 0 and is_integer(teams) and teams > 0 do
    %{
      value: ceil(work / teams),
      unit: "s",
      model_version: Engine.model_version(),
      explanation: "ceil(remaining_work / teams); one work unit per team per second"
    }
  end

  def evaluate(_, _), do: {:error, :invalid_inputs_or_model}
end
