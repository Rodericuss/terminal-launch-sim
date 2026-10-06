defmodule Engine.Progression do
  @moduledoc "Pure campaign research rules for the first technology unlocks."

  @filter_cost 2
  @network_cost 3

  def new, do: %{schema_version: 1, points: 0, tier: 0, next_run: 1, completed_keys: []}

  def status(profile) do
    %{
      points: profile.points,
      tier: profile.tier,
      filter_unlocked: profile.tier >= 1,
      network_unlocked: profile.tier >= 2,
      next_unlock: next_unlock(profile.tier),
      future: ["apoio à decisão", "supercomputação"]
    }
  end

  defp next_unlock(0),
    do: %{
      id: "filter",
      title: "Bancada de filtragem",
      cost: @filter_cost,
      effect: "altitude ±5 m → ±3 m; prazo estimado ±1 s → 0 s"
    }

  defp next_unlock(1),
    do: %{
      id: "network",
      title: "Rede de sensores",
      cost: @network_cost,
      effect: "dois sensores de altitude; alerta de prazo na central"
    }

  defp next_unlock(2), do: nil

  def unlock(profile, "filter") do
    cond do
      profile.tier >= 1 -> {:error, :already_unlocked}
      profile.points < @filter_cost -> {:error, :not_enough_points}
      true -> {:ok, %{profile | tier: 1, points: profile.points - @filter_cost}}
    end
  end

  def unlock(profile, "network") do
    cond do
      profile.tier >= 2 -> {:error, :already_unlocked}
      profile.tier < 1 -> {:error, :prerequisite_required}
      profile.points < @network_cost -> {:error, :not_enough_points}
      true -> {:ok, %{profile | tier: 2, points: profile.points - @network_cost}}
    end
  end

  def unlock(_, _), do: {:error, :unknown_technology}

  @doc "Reward a completed, previously unseen mode/seed pair only once."
  def reward(profile, %{mode: mode, seed: seed, status: status}) do
    key = "#{mode}:#{seed}"
    points = if status == :success, do: 2, else: if(status == :partial, do: 1, else: 0)

    if points > 0 and key not in profile.completed_keys do
      {%{
         profile
         | points: profile.points + points,
           completed_keys: [key | profile.completed_keys]
       }, points}
    else
      {profile, 0}
    end
  end

  def from_json(%{
        "schema_version" => 1,
        "points" => points,
        "tier" => tier,
        "next_run" => next_run,
        "completed_keys" => keys
      })
      when is_integer(points) and points >= 0 and tier in [0, 1, 2] and
             is_integer(next_run) and next_run >= 1 and is_list(keys) do
    if Enum.all?(keys, &is_binary/1) do
      {:ok,
       %{schema_version: 1, points: points, tier: tier, next_run: next_run, completed_keys: keys}}
    else
      {:error, :invalid_profile}
    end
  end

  def from_json(_), do: {:error, :invalid_profile}
end
