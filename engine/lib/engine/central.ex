defmodule Engine.Central do
  @moduledoc "Fictional command exercise about coordinating two signal incidents."

  @contacts [
    %{
      id: :orion,
      label: "Estação Órion",
      deadline_s: 12,
      work_required: 4,
      work: 0,
      assigned: 0,
      status: :open
    },
    %{
      id: :vega,
      label: "Estação Vega",
      deadline_s: 18,
      work_required: 6,
      work: 0,
      assigned: 0,
      status: :open
    }
  ]

  def new(base),
    do: Map.merge(base, %{contacts: @contacts, available_teams: 2, signal_jitter_s: 0})

  def command(state, {:assign, id}) do
    cond do
      state.available_teams < 1 ->
        {:error, :no_team_available}

      !Enum.any?(state.contacts, &(&1.id == id and &1.status == :open)) ->
        {:error, :unknown_or_closed_contact}

      true ->
        contacts =
          Enum.map(state.contacts, fn c ->
            if c.id == id, do: %{c | assigned: c.assigned + 1}, else: c
          end)

        {:ok, %{state | contacts: contacts, available_teams: state.available_teams - 1},
         [%{type: :team_assigned, contact: id}]}
    end
  end

  def command(state, {:recall, id}) do
    if Enum.any?(state.contacts, &(&1.id == id and &1.status == :open and &1.assigned > 0)) do
      contacts =
        Enum.map(state.contacts, fn c ->
          if c.id == id, do: %{c | assigned: c.assigned - 1}, else: c
        end)

      {:ok, %{state | contacts: contacts, available_teams: state.available_teams + 1},
       [%{type: :team_recalled, contact: id}]}
    else
      {:error, :no_team_assigned}
    end
  end

  def command(state, :wait), do: {:ok, state, []}
  def command(_, _), do: {:error, :invalid_command}

  def tick(state) do
    {contacts, events, freed} =
      Enum.reduce(state.contacts, {[], [], 0}, fn contact, {acc, ev, released} ->
        updated =
          if contact.status == :open,
            do: %{contact | work: contact.work + contact.assigned},
            else: contact

        cond do
          updated.status != :open ->
            {[updated | acc], ev, released}

          updated.work >= updated.work_required ->
            done = %{updated | status: :resolved, assigned: 0}

            {[done | acc], ev ++ [%{type: :contact_resolved, contact: done.id}],
             released + updated.assigned}

          state.time_s + 1 >= updated.deadline_s ->
            missed = %{updated | status: :missed, assigned: 0}

            {[missed | acc], ev ++ [%{type: :deadline_missed, contact: missed.id}],
             released + updated.assigned}

          true ->
            {[updated | acc], ev, released}
        end
      end)

    contacts = Enum.reverse(contacts)
    {next, sample} = Engine.random(state)

    status =
      if Enum.all?(contacts, &(&1.status != :open)) do
        if Enum.all?(contacts, &(&1.status == :resolved)), do: :success, else: :partial
      else
        :active
      end

    {%{
       next
       | contacts: contacts,
         available_teams: state.available_teams + freed,
         status: status,
         signal_jitter_s: if(state.tech_level >= 1, do: 0, else: floor(sample * 3) - 1)
     }, events}
  end

  def observe(state) do
    %{
      mode: :central,
      model_version: state.model_version,
      time_s: state.time_s,
      status: state.status,
      available_teams: state.available_teams,
      deadline_uncertainty_s: if(state.tech_level >= 1, do: 0, else: 1),
      tech_level: state.tech_level,
      contacts:
        Enum.map(state.contacts, fn contact ->
          contact
          |> Map.take([:id, :label, :work_required, :work, :assigned, :status])
          |> Map.put(
            :estimated_remaining_s,
            max(0, contact.deadline_s - state.time_s + state.signal_jitter_s)
          )
        end)
    }
  end
end
