defmodule HealthStreamWeb.Components.AlertNotification do
  @moduledoc """
  Alert notification component for displaying patient alerts.
  """
  use Phoenix.Component
  use Gettext, backend: HealthStreamWeb.Gettext

  import HealthStreamWeb.CoreComponents

  @doc """
  Renders an alert notification.

  ## Examples

      <.alert_notification vital_sign={vital_sign} alerts={alerts} timestamp={timestamp} />
  """
  attr :vital_sign, :map, required: true, doc: "The vital sign data containing patient_id"
  attr :alerts, :list, required: true, doc: "List of alert tuples {type, value, severity}"
  attr :timestamp, :any, required: true, doc: "When the alert was created"

  def alert_notification(assigns) do
    ~H"""
    <article
      class="card bg-base-200 border"
      role="alert"
      aria-label={"Alert for patient #{@vital_sign.patient_id}"}
    >
      <div class="card-body p-4">
        <header class="flex justify-between items-start mb-2">
          <h4 class="font-semibold">Patient {@vital_sign.patient_id}</h4>
          <time class="text-sm opacity-70" datetime={@timestamp}>
            {format_timestamp(@timestamp)}
          </time>
        </header>

        <div class="flex flex-wrap gap-2" role="list">
          <div
            :for={{type, value, severity} <- @alerts}
            class={get_alert_component_class(severity)}
            role="listitem"
          >
            <.icon name="hero-exclamation-triangle" class="size-4" />
            <div>
              <strong>{format_alert_type(type)}:</strong> {format_alert_value(type, value)}
              <span class="ml-1 font-semibold">({String.upcase(to_string(severity))})</span>
            </div>
          </div>
        </div>
      </div>
    </article>
    """
  end

  # Helper functions
  defp format_timestamp(nil), do: "—"
  defp format_timestamp(timestamp), do: DateTime.to_string(timestamp)

  defp get_alert_component_class(:critical), do: "alert alert-error"
  defp get_alert_component_class(:alert), do: "alert alert-warning"
  defp get_alert_component_class(_), do: "alert alert-info"

  defp format_alert_type(:heart_rate), do: "Heart Rate"
  defp format_alert_type(:blood_pressure), do: "Blood Pressure"
  defp format_alert_type(:oxygen_saturation), do: "Oxygen Saturation"
  defp format_alert_type(:temperature), do: "Temperature"

  defp format_alert_value(:heart_rate, value), do: "#{value} BPM"
  defp format_alert_value(:blood_pressure, value), do: "#{value} mmHg"
  defp format_alert_value(:oxygen_saturation, value), do: "#{value}%"
  defp format_alert_value(:temperature, value), do: "#{value}°F"
end
