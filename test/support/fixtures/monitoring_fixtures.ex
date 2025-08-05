defmodule HealthStream.MonitoringFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HealthStream.Monitoring` context.
  """

  @doc """
  Generate a vital_sign.
  """
  def vital_sign_fixture(attrs \\ %{}) do
    {:ok, vital_sign} =
      attrs
      |> Enum.into(%{
        device_id: "some device_id",
        inserted_at: ~U[2025-08-04 17:28:00Z],
        measurements: %{
          heart_rate: 80,
          blood_pressure_sys: 120,
          blood_pressure_dia: 80,
          oxygen_saturation: 98,
          temperature: 82
        },
        patient_id: "some patient_id"
      })
      |> HealthStream.Monitoring.create_vital_sign()

    vital_sign
  end
end
