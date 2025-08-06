defmodule HealthStreamWeb.Components.VitalMeasurement do
  @moduledoc """
  Vital signs measurement card component.
  """
  use Phoenix.Component
  use Gettext, backend: HealthStreamWeb.Gettext

  @doc """
  Renders a vital signs measurement card.

  ## Examples

      <.vital_measurement
        title="Heart Rate"
        value={75}
        unit="BPM"
        alert_severity={:critical} />

      <.vital_measurement
        title="Blood Pressure"
        value="120/80"
        unit="mmHg" />
  """
  attr :title, :string, required: true, doc: "The measurement title (e.g., 'Heart Rate')"
  attr :value, :any, required: true, doc: "The measurement value"
  attr :unit, :string, required: true, doc: "The measurement unit (e.g., 'BPM', 'mmHg')"

  attr :alert_severity, :atom,
    values: [:critical, :alert],
    doc: "Alert severity level"

  attr :class, :string, default: "", doc: "Additional CSS classes for styling"

  def vital_measurement(assigns) do
    ~H"""
    <article class={["card bg-base-100 border", @class]} role="region" aria-label={@title}>
      <div class="card-body p-3">
        <h3 class="text-xs uppercase font-medium opacity-70">{@title}</h3>
        <div class="text-xl font-bold">
          {@value}
          <span class="text-sm font-normal opacity-70">{@unit}</span>
        </div>
        <div :if={@alert_severity} class="badge badge-error badge-sm font-medium" role="alert">
          {String.upcase(to_string(@alert_severity))} ALERT
        </div>
      </div>
    </article>
    """
  end
end
