defmodule Engine.Space do
  @moduledoc "One-dimensional sounding rocket model; see docs/MODELS.md."

  @gravity 9.81
  @sea_density 1.225
  @scale_height 8_500.0
  @dry_mass 80.0
  @initial_fuel 100.0
  @thrust 4_000.0
  @burn_rate 2.0
  @drag_area 0.12
  @target_altitude 2_000.0

  def new(base) do
    Map.merge(base, %{
      phase: :ready,
      altitude_m: 0.0,
      velocity_m_s: 0.0,
      fuel_kg: @initial_fuel,
      peak_altitude_m: 0.0,
      observed_altitude_m: 0,
      observed_velocity_m_s: 0,
      primary_altitude_m: 0,
      secondary_altitude_m: 0,
      sensor_disagreement_m: 0,
      last_sensor_alert_s: -10,
      check_complete: false
    })
  end

  def command(%{phase: :ready} = state, :check),
    do: {:ok, %{state | check_complete: true}, [%{type: :check_complete}]}

  def command(%{phase: :ready, check_complete: true} = state, :launch),
    do: {:ok, %{state | phase: :powered}, [%{type: :launched}]}

  def command(%{phase: :ready}, :launch), do: {:error, :check_required}

  def command(%{phase: phase} = state, :abort) when phase in [:ready, :powered, :coast],
    do: {:ok, %{state | phase: :aborted, status: :failed}, [%{type: :aborted}]}

  def command(state, :wait), do: {:ok, state, []}
  def command(_, _), do: {:error, :invalid_command}

  def tick(%{phase: phase} = state) when phase in [:ready, :aborted, :landed], do: {state, []}

  def tick(state) do
    used = if state.phase == :powered, do: min(@burn_rate, state.fuel_kg), else: 0.0
    mass = @dry_mass + state.fuel_kg - used / 2.0
    thrust = if used > 0, do: @thrust * used / @burn_rate, else: 0.0
    density = @sea_density * :math.exp(-state.altitude_m / @scale_height)
    drag = 0.5 * density * @drag_area * state.velocity_m_s * abs(state.velocity_m_s)
    velocity = state.velocity_m_s + (thrust - drag) / mass - @gravity
    altitude = max(0.0, state.altitude_m + (state.velocity_m_s + velocity) / 2.0)
    peak = max(state.peak_altitude_m, altitude)
    fuel = state.fuel_kg - used
    phase = if fuel <= 0 and state.phase == :powered, do: :coast, else: state.phase
    {noisy, sample} = Engine.random(state)
    primary = max(0, round(altitude + (sample * 2.0 - 1.0) * uncertainty(state)))

    {measured, observed, secondary, disagreement, sensor_events, last_alert} =
      if state.tech_level >= 2 do
        {twice_noisy, second_sample} = Engine.random(noisy)
        secondary = max(0, round(altitude + (second_sample * 2.0 - 1.0) * 3))
        difference = abs(primary - secondary)
        alert = difference >= 4 and state.time_s + 1 - state.last_sensor_alert_s >= 10
        events = if alert, do: [%{type: :sensor_disagreement, difference_m: difference}], else: []
        last_alert = if alert, do: state.time_s + 1, else: state.last_sensor_alert_s
        {twice_noisy, round((primary + secondary) / 2), secondary, difference, events, last_alert}
      else
        {noisy, primary, 0, 0, [], state.last_sensor_alert_s}
      end

    next = %{
      measured
      | phase: phase,
        altitude_m: altitude,
        velocity_m_s: velocity,
        fuel_kg: fuel,
        peak_altitude_m: peak,
        observed_altitude_m: observed,
        observed_velocity_m_s: round(velocity),
        primary_altitude_m: primary,
        secondary_altitude_m: secondary,
        sensor_disagreement_m: disagreement,
        last_sensor_alert_s: last_alert
    }

    cond do
      altitude <= 0 and state.altitude_m > 0 and velocity < 0 ->
        result = if peak >= @target_altitude, do: :success, else: :partial

        {%{next | phase: :landed, status: result},
         sensor_events ++ [%{type: :landed, result: result, peak_altitude_m: peak}]}

      phase == :coast and state.phase == :powered ->
        {next, sensor_events ++ [%{type: :burnout}]}

      true ->
        {next, sensor_events}
    end
  end

  def observe(state) do
    observation = %{
      mode: :space,
      model_version: state.model_version,
      time_s: state.time_s,
      status: state.status,
      phase: state.phase,
      altitude_m: state.observed_altitude_m,
      velocity_m_s: state.observed_velocity_m_s,
      fuel_kg: Float.round(state.fuel_kg, 2),
      peak_altitude_m: round(state.peak_altitude_m),
      altitude_uncertainty_m: uncertainty(state),
      tech_level: state.tech_level,
      target_altitude_m: @target_altitude,
      check_complete: state.check_complete
    }

    if state.tech_level >= 2 do
      Map.merge(observation, %{
        primary_altitude_m: state.primary_altitude_m,
        secondary_altitude_m: state.secondary_altitude_m,
        sensor_disagreement_m: state.sensor_disagreement_m
      })
    else
      observation
    end
  end

  defp uncertainty(%{tech_level: level}) when level >= 1, do: 3
  defp uncertainty(_), do: 5
end
