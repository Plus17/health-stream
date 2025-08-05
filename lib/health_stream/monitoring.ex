defmodule HealthStream.Monitoring do
  @moduledoc """
  The Monitoring context.
  """

  import Ecto.Query, warn: false
  alias HealthStream.Repo

  alias HealthStream.Monitoring.VitalSign

  @doc """
  Returns the list of vital_signs.

  ## Examples

      iex> list_vital_signs()
      [%VitalSign{}, ...]

  """
  def list_vital_signs do
    Repo.all(VitalSign)
  end

  @doc """
  Gets a single vital_sign.

  Raises `Ecto.NoResultsError` if the Vital sign does not exist.

  ## Examples

      iex> get_vital_sign!(123)
      %VitalSign{}

      iex> get_vital_sign!(456)
      ** (Ecto.NoResultsError)

  """
  def get_vital_sign!(id), do: Repo.get!(VitalSign, id)

  @doc """
  Creates a vital_sign.

  ## Examples

      iex> create_vital_sign(%{field: value})
      {:ok, %VitalSign{}}

      iex> create_vital_sign(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_vital_sign(attrs) do
    %VitalSign{}
    |> VitalSign.changeset(attrs)
    |> Repo.insert()
  end

  def build_vital_sign(attrs) do
    vital_sign =
      %VitalSign{}
      |> VitalSign.changeset(attrs)
      |> Ecto.Changeset.apply_changes()
      |> Map.put(:inserted_at, DateTime.utc_now())

    {:ok, vital_sign}
  end

  @doc """
  Deletes a vital_sign.

  ## Examples

      iex> delete_vital_sign(vital_sign)
      {:ok, %VitalSign{}}

      iex> delete_vital_sign(vital_sign)
      {:error, %Ecto.Changeset{}}

  """
  def delete_vital_sign(%VitalSign{} = vital_sign) do
    Repo.delete(vital_sign)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking vital_sign changes.

  ## Examples

      iex> change_vital_sign(vital_sign)
      %Ecto.Changeset{data: %VitalSign{}}

  """
  def change_vital_sign(%VitalSign{} = vital_sign, attrs \\ %{}) do
    VitalSign.changeset(vital_sign, attrs)
  end
end
