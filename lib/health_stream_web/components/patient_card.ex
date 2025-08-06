defmodule HealthStreamWeb.Components.PatientCard do
  @moduledoc """
  Patient card component for displaying patient information and vital signs.
  """
  use Phoenix.Component
  use Gettext, backend: HealthStreamWeb.Gettext

  import HealthStreamWeb.CoreComponents
  import HealthStreamWeb.Components.VitalMeasurement

  @doc """
  Renders a patient card with vital signs.

  ## Examples

      <.patient_card patient={patient} vital_signs={vital_signs} />
  """
  attr :patient, :map, required: true
  attr :vital_signs, :map, required: true

  def patient_card(assigns) do
    ~H"""
    <article class="card bg-base-100 shadow-lg" role="region" aria-label={"Patient #{@patient.name}"}>
      <div class="card-body">
        <header class="flex justify-between items-start mb-4">
          <div>
            <h2 class="card-title">{@patient.name}</h2>
            <p class="text-sm opacity-70">ID: {@patient.id} | Device: {@patient.device}</p>
            <p class="text-sm opacity-70">Status: {vital_status(@patient.id, @vital_signs)}</p>
            <%= if vital_sign = Map.get(@vital_signs, @patient.id) do %>
              <time class="text-xs opacity-50" datetime={Map.get(vital_sign, :last_update)}>
                Last update: {format_timestamp(Map.get(vital_sign, :last_update))}
              </time>
            <% end %>
          </div>
          <div class="card-actions">
            <.button
              phx-click="toggle_patient_mode"
              phx-value-patient={@patient.id}
              variant="primary"
              aria-label={"Toggle monitoring mode for patient #{@patient.name}"}
            >
              <.icon name="hero-arrow-path" class="size-5" /> Toggle Mode
            </.button>
          </div>
        </header>

        <%= if vital_sign = Map.get(@vital_signs, @patient.id) do %>
          <section class="grid grid-cols-2 gap-4" aria-label="Vital signs measurements">
            <.vital_measurement
              title="Heart Rate"
              value={safe_get_measurement(vital_sign, :heart_rate, "—")}
              unit="BPM"
              alert_severity={get_measurement_alert_severity(vital_sign, :heart_rate)}
              class={get_measurement_card_class(vital_sign, :heart_rate)}
            />
            <.vital_measurement
              title="Blood Pressure"
              value={"#{safe_get_measurement(vital_sign, :blood_pressure_sys, "—")}/#{safe_get_measurement(vital_sign, :blood_pressure_dia, "—")}"}
              unit="mmHg"
              alert_severity={get_measurement_alert_severity(vital_sign, :blood_pressure)}
              class={get_measurement_card_class(vital_sign, :blood_pressure)}
            />
            <.vital_measurement
              title="Oxygen Saturation"
              value={safe_get_measurement(vital_sign, :oxygen_saturation, "—")}
              unit="%"
              alert_severity={get_measurement_alert_severity(vital_sign, :oxygen_saturation)}
              class={get_measurement_card_class(vital_sign, :oxygen_saturation)}
            />
            <.vital_measurement
              title="Temperature"
              value={safe_get_measurement(vital_sign, :temperature, "—")}
              unit="°F"
              alert_severity={get_measurement_alert_severity(vital_sign, :temperature)}
              class={get_measurement_card_class(vital_sign, :temperature)}
            />
          </section>
        <% else %>
          <div class="text-center py-8 opacity-60" role="status" aria-live="polite">
            <div class="text-lg">⏳</div>
            <p class="mt-2">Waiting for vital signs data...</p>
          </div>
        <% end %>
      </div>
    </article>
    """
  end

  # Helper functions that will be moved from MonitoringLive
  defp vital_status(patient_id, vital_signs) do
    case Map.get(vital_signs, patient_id) do
      nil -> "No data"
      _vital_sign -> "Monitoring"
    end
  end

  defp format_timestamp(nil), do: "—"
  defp format_timestamp(timestamp), do: DateTime.to_string(timestamp)

  defp safe_get_measurement(vital_sign, field, default) do
    case vital_sign.measurements do
      nil ->
        default

      measurements ->
        case Map.get(measurements, field) do
          nil -> default
          value when is_float(value) -> Float.round(value, 1)
          value -> value
        end
    end
  rescue
    _ -> default
  end

  defp get_measurement_alert_severity(vital_sign, measurement_type) do
    alerts = Map.get(vital_sign, :current_alerts, [])

    case Enum.find(alerts, fn {type, _value, _severity} -> type == measurement_type end) do
      {_type, _value, severity} -> severity
      nil -> nil
    end
  end

  defp get_measurement_card_class(vital_sign, measurement_type) do
    case get_measurement_alert_severity(vital_sign, measurement_type) do
      :critical -> "border-error bg-error/10"
      :alert -> "border-warning bg-warning/10"
      _ -> "border-base-300"
    end
  end
end
