defmodule Engine.ProgressionStore do
  @moduledoc "Atomic local JSON storage for the prototype's campaign profile."

  alias Engine.Progression

  def path do
    System.get_env("TLS_PROFILE_PATH") ||
      Path.join([
        System.get_env("XDG_DATA_HOME") || Path.join(System.user_home!(), ".local/share"),
        "terminal-launch-sim",
        "profile.json"
      ])
  end

  def load do
    case File.read(path()) do
      {:ok, data} ->
        with {:ok, decoded} <- Jason.decode(data),
             {:ok, profile} <- Progression.from_json(decoded) do
          {:ok, profile}
        else
          _ -> {:error, :invalid_profile}
        end

      {:error, :enoent} ->
        {:ok, Progression.new()}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def save(profile) do
    destination = path()
    temporary = destination <> ".#{System.unique_integer([:positive])}.tmp"

    with :ok <- File.mkdir_p(Path.dirname(destination)),
         :ok <- File.write(temporary, Jason.encode!(profile)),
         :ok <- File.rename(temporary, destination) do
      :ok
    else
      {:error, _reason} = error ->
        File.rm(temporary)
        error
    end
  end
end
