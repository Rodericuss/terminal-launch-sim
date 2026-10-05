defmodule Engine.ProtocolTest do
  use ExUnit.Case

  alias Engine.Protocol

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

  test "creates both modes with only observable data in snapshots" do
    for mode <- ["space", "central"] do
      {reply, _} =
        Protocol.handle_line(
          request("create-#{mode}", "run.create", nil, 0, %{mode: mode, seed: 42}),
          Protocol.new_server()
        )

      snapshot = reply.payload.data.snapshot
      assert reply.payload.ok
      assert snapshot.observation.mode == String.to_existing_atom(mode)
      refute Map.has_key?(snapshot.observation, :rng)
      refute Map.has_key?(snapshot.observation, :seed)
      refute Map.has_key?(snapshot.observation, :log)
    end
  end

  test "duplicate command request_id does not advance twice" do
    {created, server} =
      Protocol.handle_line(
        request("create", "run.create", nil, 0, %{mode: "space", seed: 42}),
        Protocol.new_server()
      )

    run_id = created.run_id
    command = request("check-1", "run.command", run_id, 0, %{command: "check"})
    {first, server} = Protocol.handle_line(command, server)
    {duplicate, server} = Protocol.handle_line(command, server)
    assert duplicate == first
    assert first.seq == 1

    {snapshot, _} =
      Protocol.handle_line(request("snapshot", "run.snapshot", run_id, 1, %{}), server)

    assert snapshot.seq == 1
    assert snapshot.payload.data.snapshot.observation.check_complete
  end

  test "bad JSON, invalid command and stale sequence return errors without mutation" do
    {malformed, server} = Protocol.handle_line("{bad\n", Protocol.new_server())
    assert malformed.payload.error.code == "malformed_json"

    {created, server} =
      Protocol.handle_line(
        request("create", "run.create", nil, 0, %{mode: "central", seed: 42}),
        server
      )

    run_id = created.run_id

    {bad, server} =
      Protocol.handle_line(request("bad", "run.command", run_id, 0, %{command: "launch"}), server)

    assert bad.payload.error.code == "invalid_command"

    {good, server} =
      Protocol.handle_line(
        request("good", "run.command", run_id, 0, %{command: "wait 2"}),
        server
      )

    assert good.seq == 2

    {stale, _} =
      Protocol.handle_line(request("stale", "run.command", run_id, 0, %{command: "wait"}), server)

    assert stale.payload.error.code == "sequence_mismatch"
    assert stale.seq == 2
  end

  test "calculator responds with a versioned result" do
    {reply, _} =
      Protocol.handle_line(
        request("calc", "calculator.evaluate", nil, 0, %{
          model: "average_speed",
          inputs: %{distance_m: 100, time_s: 20}
        }),
        Protocol.new_server()
      )

    assert reply.payload.data.result.value == 5.0
    assert reply.payload.data.result.unit == "m/s"
  end
end
