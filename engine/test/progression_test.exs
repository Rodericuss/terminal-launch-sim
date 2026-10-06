defmodule Engine.ProgressionTest do
  use ExUnit.Case

  alias Engine.{Progression, ProgressionStore, Protocol}

  defp request(id, type, run_id, seq, payload) do
    Jason.encode!(%{
      protocol_version: 1,
      request_id: id,
      run_id: run_id,
      seq: seq,
      type: type,
      payload: payload
    })
  end

  defp send_request(server, id, type, run_id, seq, payload) do
    Protocol.handle_line(request(id, type, run_id, seq, payload), server)
  end

  test "research reward unlocks filter in later runs and keeps mission rules" do
    {created, server} =
      send_request(Protocol.new_server(), "create", "run.create", nil, 0, %{
        mode: "central",
        seed: 42
      })

    run_id = created.run_id

    {_, server} =
      send_request(server, "assign-o", "run.command", run_id, 0, %{command: "assign orion"})

    {_, server} =
      send_request(server, "assign-v", "run.command", run_id, 1, %{command: "assign vega"})

    {finished, server} =
      send_request(server, "finish", "run.command", run_id, 2, %{command: "wait 10"})

    assert finished.payload.data.snapshot.observation.status == :success
    assert finished.payload.data.research_points_earned == 2
    assert server.profile.points == 2

    {unlocked, server} = send_request(server, "unlock", "tech.unlock", nil, 0, %{id: "filter"})
    assert unlocked.payload.data.profile.tier == 1
    assert unlocked.payload.data.profile.points == 0

    {next_run, _server} =
      send_request(server, "create-2", "run.create", nil, 0, %{mode: "central", seed: 43})

    assert next_run.payload.data.snapshot.observation.deadline_uncertainty_s == 0

    base = Engine.new(:space, 42, 0)
    filtered = Engine.new(:space, 42, 1)
    assert Engine.observe(base).altitude_uncertainty_m == 5
    assert Engine.observe(filtered).altitude_uncertainty_m == 3
    {:ok, base, _} = Engine.step(base, :check, 1)
    {:ok, filtered, _} = Engine.step(filtered, :check, 1)
    {:ok, base, _} = Engine.step(base, :launch, 1)
    {:ok, filtered, _} = Engine.step(filtered, :launch, 1)
    assert base.altitude_m == filtered.altitude_m
    assert base.velocity_m_s == filtered.velocity_m_s
  end

  test "same mode and seed receive research points only once" do
    profile = Progression.new()
    completed = %{mode: :central, seed: 42, status: :success}
    {profile, 2} = Progression.reward(profile, completed)
    {again, 0} = Progression.reward(profile, completed)
    assert again == profile
  end

  test "campaign profile survives a store reload" do
    path = Path.join(System.tmp_dir!(), "tls-profile-#{System.unique_integer([:positive])}.json")
    previous = System.get_env("TLS_PROFILE_PATH")
    System.put_env("TLS_PROFILE_PATH", path)

    try do
      profile = %{Progression.new() | points: 3, tier: 1, next_run: 5}
      assert :ok = ProgressionStore.save(profile)
      assert {:ok, ^profile} = ProgressionStore.load()
    after
      File.rm(path)

      if previous,
        do: System.put_env("TLS_PROFILE_PATH", previous),
        else: System.delete_env("TLS_PROFILE_PATH")
    end
  end
end
