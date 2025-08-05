defmodule HealthStream.Monitoring.VitalSign do
  use Ecto.Schema
  import Ecto.Changeset

  alias HealthStream.Monitoring.Measurements

  schema "vital_signs" do
    field :patient_id, :string
    field :device_id, :string
    embeds_one :measurements, Measurements

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(vital_sign, attrs) do
    vital_sign
    |> cast(attrs, [:patient_id, :device_id])
    |> cast_embed(:measurements, required: true)
    |> validate_required([:patient_id, :device_id])
  end
end
