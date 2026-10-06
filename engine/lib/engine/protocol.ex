defmodule Engine.Protocol do
  @moduledoc "Line-delimited JSON adapter for the local terminal client."

  @version 1
  @max_line_bytes 65_536

  @type session :: %{state: map()}

  def main(_args) do
    case Engine.ProgressionStore.load() do
      {:ok, profile} ->
        loop(new_server(profile))

      {:error, reason} ->
        IO.puts(:stderr, "Unable to load campaign profile: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp loop(server) do
    case IO.gets(:stdio, "") do
      :eof ->
        :ok

      line ->
        {reply, next} = handle_line(line, server)

        if next.profile != server.profile do
          case Engine.ProgressionStore.save(next.profile) do
            :ok ->
              IO.puts(Jason.encode!(reply))
              loop(next)

            {:error, reason} ->
              IO.puts(:stderr, "Unable to save campaign profile: #{inspect(reason)}")

              failed =
                error(
                  reply.request_id,
                  reply.run_id,
                  reply.seq,
                  "profile_save_failed",
                  "Campaign progress could not be saved"
                )

              IO.puts(Jason.encode!(failed))
              loop(server)
          end
        else
          IO.puts(Jason.encode!(reply))
          loop(next)
        end
    end
  end

  @doc "Process one line without IO; returns a response and the next server state."
  def handle_line(line, server) when is_binary(line) and is_map(server) do
    cond do
      byte_size(line) > @max_line_bytes ->
        {error(nil, nil, 0, "request_too_large", "Message exceeds 65536 bytes"), server}

      true ->
        case Jason.decode(line) do
          {:ok, request} -> handle(request, server)
          {:error, _} -> {error(nil, nil, 0, "malformed_json", "Invalid JSON"), server}
        end
    end
  rescue
    exception ->
      IO.puts(:stderr, "protocol error: #{Exception.message(exception)}")
      {error(nil, nil, 0, "internal_error", "Unable to process request"), server}
  end

  def new_server(profile \\ Engine.Progression.new()),
    do: %{runs: %{}, profile: profile, responses: %{}}

  defp handle(request, server) when is_map(request) do
    request_id = Map.get(request, "request_id")
    run_id = Map.get(request, "run_id")
    seq = Map.get(request, "seq", 0)

    cond do
      request["protocol_version"] != @version ->
        {error(request_id, run_id, seq, "unsupported_protocol", "Protocol version must be 1"),
         server}

      !is_binary(request_id) or request_id == "" or byte_size(request_id) > 128 ->
        {error(nil, run_id, seq, "invalid_request_id", "request_id must be a nonempty string"),
         server}

      !is_integer(seq) or seq < 0 ->
        {error(request_id, run_id, 0, "invalid_sequence", "seq must be a nonnegative integer"),
         server}

      Map.has_key?(server.responses, request_id) ->
        {server.responses[request_id], server}

      !is_map(request["payload"]) ->
        remember(
          error(request_id, run_id, seq, "invalid_payload", "payload must be an object"),
          server
        )

      true ->
        {reply, next} = dispatch(request, server)
        remember(reply, next)
    end
  end

  defp handle(_, server),
    do: {error(nil, nil, 0, "invalid_request", "Request must be an object"), server}

  defp dispatch(%{"type" => "catalog.list"} = request, server) do
    data = %{
      model_version: Engine.model_version(),
      modes: [
        %{
          id: "space",
          title: "Programa espacial",
          commands: ["check", "launch", "abort", "wait [1..500]"]
        },
        %{
          id: "central",
          title: "Central fictícia",
          commands: ["assign orion|vega", "recall orion|vega", "wait [1..500]"]
        }
      ]
    }

    {ok(request, nil, request["seq"], data), server}
  end

  defp dispatch(%{"type" => "run.create", "payload" => payload} = request, server) do
    mode =
      case payload["mode"] do
        "space" -> :space
        "central" -> :central
        _ -> nil
      end

    seed = payload["seed"]

    if mode && is_integer(seed) && seed >= 0 do
      run_id = "run-#{server.profile.next_run}"
      state = Engine.new(mode, seed, server.profile.tier)

      next = %{
        server
        | profile: %{server.profile | next_run: server.profile.next_run + 1},
          runs: Map.put(server.runs, run_id, %{state: state})
      }

      {ok(request, run_id, 0, %{snapshot: snapshot(run_id, state, [])}), next}
    else
      {request_error(
         request,
         0,
         "invalid_mode_or_seed",
         "mode must be space or central; seed must be nonnegative"
       ), server}
    end
  end

  defp dispatch(%{"type" => "run.snapshot"} = request, server) do
    with {:ok, state} <- find_run(server, request["run_id"]) do
      {ok(request, request["run_id"], state.tick, %{
         snapshot: snapshot(request["run_id"], state, [])
       }), server}
    else
      {:error, code, message} -> {request_error(request, 0, code, message), server}
    end
  end

  defp dispatch(%{"type" => "run.command", "payload" => payload} = request, server) do
    run_id = request["run_id"]

    with {:ok, state} <- find_run(server, run_id),
         :ok <- require_seq(request["seq"], state.tick),
         {:ok, command, count} <- parse_command(payload["command"], state.mode),
         {:ok, updated, events} <- advance(state, command, count) do
      {profile, points} =
        if state.status == :active and updated.status != :active,
          do: Engine.Progression.reward(server.profile, updated),
          else: {server.profile, 0}

      next = server |> put_in([:runs, run_id, :state], updated) |> Map.put(:profile, profile)

      {ok(request, run_id, updated.tick, %{
         snapshot: snapshot(run_id, updated, events),
         research_points_earned: points
       }), next}
    else
      {:error, code, message} ->
        current_seq =
          case Map.get(server.runs, run_id) do
            %{state: state} -> state.tick
            _ -> 0
          end

        {request_error(request, current_seq, code, message), server}
    end
  end

  defp dispatch(%{"type" => "tech.status"} = request, server) do
    {ok(request, nil, request["seq"], %{profile: Engine.Progression.status(server.profile)}),
     server}
  end

  defp dispatch(%{"type" => "tech.unlock", "payload" => payload} = request, server) do
    case Engine.Progression.unlock(server.profile, payload["id"]) do
      {:ok, profile} ->
        {ok(request, nil, request["seq"], %{profile: Engine.Progression.status(profile)}),
         %{server | profile: profile}}

      {:error, reason} ->
        {request_error(
           request,
           request["seq"],
           Atom.to_string(reason),
           "Technology unlock rejected: #{reason}"
         ), server}
    end
  end

  defp dispatch(%{"type" => "calculator.evaluate", "payload" => payload} = request, server) do
    model =
      case payload["model"] do
        "average_speed" -> :average_speed
        "work_eta" -> :work_eta
        _ -> nil
      end

    inputs = payload["inputs"]

    result =
      if model && is_map(inputs) do
        Engine.Calculator.evaluate(model, stringify_keys_to_existing_atoms(inputs, model))
      else
        {:error, :invalid_inputs_or_model}
      end

    case result do
      %{} = value ->
        {ok(request, request["run_id"], request["seq"], %{result: value}), server}

      {:error, _} ->
        {request_error(
           request,
           request["seq"],
           "invalid_inputs_or_model",
           "Invalid calculator model or inputs"
         ), server}
    end
  end

  defp dispatch(request, server) do
    {request_error(request, request["seq"], "unknown_operation", "Unknown operation"), server}
  end

  defp find_run(server, run_id) when is_binary(run_id) do
    case Map.get(server.runs, run_id) do
      %{state: state} -> {:ok, state}
      _ -> {:error, "run_not_found", "Unknown run_id"}
    end
  end

  defp find_run(_, _), do: {:error, "run_not_found", "Unknown run_id"}

  defp require_seq(seq, seq), do: :ok

  defp require_seq(_, _),
    do: {:error, "sequence_mismatch", "Fetch run.snapshot and retry with its seq"}

  defp parse_command("wait", _), do: {:ok, :wait, 1}

  defp parse_command("wait " <> count, _) do
    case Integer.parse(count) do
      {n, ""} when n in 1..500 -> {:ok, :wait, n}
      _ -> {:error, "invalid_command", "wait count must be between 1 and 500"}
    end
  end

  defp parse_command("check", :space), do: {:ok, :check, 1}
  defp parse_command("launch", :space), do: {:ok, :launch, 1}
  defp parse_command("abort", :space), do: {:ok, :abort, 1}
  defp parse_command("assign orion", :central), do: {:ok, {:assign, :orion}, 1}
  defp parse_command("assign vega", :central), do: {:ok, {:assign, :vega}, 1}
  defp parse_command("recall orion", :central), do: {:ok, {:recall, :orion}, 1}
  defp parse_command("recall vega", :central), do: {:ok, {:recall, :vega}, 1}
  defp parse_command(_, _), do: {:error, "invalid_command", "Command is not valid for this mode"}

  defp advance(state, command, count) do
    Enum.reduce_while(1..count, {:ok, state, []}, fn _, {:ok, current, events} ->
      case Engine.step(current, command, 1) do
        {:ok, updated, fresh} ->
          next = {:ok, updated, events ++ fresh}
          if updated.status == :active, do: {:cont, next}, else: {:halt, next}

        {:error, reason} ->
          {:halt, {:error, Atom.to_string(reason), "Command rejected: #{reason}"}}
      end
    end)
  end

  defp stringify_keys_to_existing_atoms(inputs, :average_speed) do
    %{distance_m: inputs["distance_m"], time_s: inputs["time_s"]}
  end

  defp stringify_keys_to_existing_atoms(inputs, :work_eta) do
    %{remaining_work: inputs["remaining_work"], teams: inputs["teams"]}
  end

  defp snapshot(run_id, state, events) do
    %{run_id: run_id, seq: state.tick, observation: Engine.observe(state), events: events}
  end

  defp ok(request, run_id, seq, data) do
    envelope(request["request_id"], run_id, seq, %{ok: true, data: data})
  end

  defp request_error(request, seq, code, message) do
    error(request["request_id"], request["run_id"], seq, code, message)
  end

  defp error(request_id, run_id, seq, code, message) do
    envelope(request_id, run_id, seq, %{ok: false, error: %{code: code, message: message}})
  end

  defp envelope(request_id, run_id, seq, payload) do
    %{
      protocol_version: @version,
      request_id: request_id,
      run_id: run_id,
      seq: seq,
      type: "response",
      payload: payload
    }
  end

  defp remember(reply, server) do
    {reply, put_in(server, [:responses, reply.request_id], reply)}
  end
end
