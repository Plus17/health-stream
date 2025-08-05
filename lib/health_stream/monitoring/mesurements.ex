defmodule HealthStream.Monitoring.Measurements do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :heart_rate, :integer
    field :blood_pressure_sys, :integer
    field :blood_pressure_dia, :integer
    field :oxygen_saturation, :integer
    field :temperature, :float
  end

  def changeset(measurements, attrs) do
    measurements
    |> cast(attrs, [
      :heart_rate,
      :blood_pressure_sys,
      :blood_pressure_dia,
      :oxygen_saturation,
      :temperature
    ])
    |> validate_required([
      :heart_rate,
      :blood_pressure_sys,
      :blood_pressure_dia,
      :oxygen_saturation,
      :temperature
    ])
    |> validate_number(:heart_rate, greater_than: 0, less_than: 300)
    |> validate_number(:blood_pressure_sys, greater_than: 0, less_than: 300)
    |> validate_number(:blood_pressure_dia, greater_than: 0, less_than: 200)
    |> validate_number(:oxygen_saturation, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:temperature, greater_than: 80.0, less_than: 120.0)
  end
end
