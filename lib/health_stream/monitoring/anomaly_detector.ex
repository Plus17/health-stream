defmodule HealthStream.Monitoring.AnomalyDetector do
  @moduledoc """
  Detects anomalies in vital signs based on medical thresholds.
  """

  alias HealthStream.Monitoring.VitalSign
  alias HealthStream.Monitoring.Measurements

  @type measure_type :: :heart_rate | :blood_pressure | :oxygen_saturation | :temperature
  @type alert :: {measure_type(), any(), :alert | :critical}

  @doc """
  Checks vital signs for anomalies and returns a list of alerts.
  """
  @spec check_anomalies(VitalSign.t()) :: [alert()]
  def check_anomalies(%VitalSign{measurements: measurements}) do
    []
    |> check_heart_rate(measurements)
    |> check_blood_pressure(measurements)
    |> check_oxygen_saturation(measurements)
    |> check_temperature(measurements)
  end

  # Heart Rate: Normal 60-100 BPM, Critical <40 or >150
  defp check_heart_rate(alerts, %Measurements{heart_rate: hr}) when hr < 60 or hr > 100 do
    severity = if hr < 40 or hr > 150, do: :critical, else: :alert
    [{:heart_rate, hr, severity} | alerts]
  end

  defp check_heart_rate(alerts, _measurements), do: alerts

  # Blood Pressure: Normal Sys <140, Dia <90, Critical Sys >180 or Dia >120
  defp check_blood_pressure(alerts, %Measurements{} = measurements) do
    %{blood_pressure_sys: sys, blood_pressure_dia: dia} = measurements

    cond do
      sys >= 140 or dia >= 90 ->
        severity = if sys > 180 or dia > 120, do: :critical, else: :alert
        [{:blood_pressure, "#{sys}/#{dia}", severity} | alerts]

      sys < 90 or dia < 60 ->
        [{:blood_pressure, "#{sys}/#{dia}", :alert} | alerts]

      true ->
        alerts
    end
  end

  # Oxygen Saturation: Normal >95%, Critical <90%
  defp check_oxygen_saturation(alerts, %Measurements{oxygen_saturation: o2}) when o2 < 95 do
    severity = if o2 < 90, do: :critical, else: :alert
    [{:oxygen_saturation, o2, severity} | alerts]
  end

  defp check_oxygen_saturation(alerts, _measurements), do: alerts

  # Temperature: Normal 97-100.4°F, Critical <95 or >104°F
  defp check_temperature(alerts, %Measurements{temperature: temp}) do
    cond do
      temp < 97.0 or temp > 100.4 ->
        severity = if temp < 95.0 or temp > 104.0, do: :critical, else: :alert
        [{:temperature, temp, severity} | alerts]

      true ->
        alerts
    end
  end
end
