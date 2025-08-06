defmodule HealthStreamWeb.MonitoringLive do
  use HealthStreamWeb, :live_view

  alias HealthStream.DeviceSimulator
  require Logger

  import HealthStreamWeb.Components.PatientCard
  import HealthStreamWeb.Components.AlertNotification
  import HealthStreamWeb.Components.StatusIndicator

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(HealthStream.PubSub, "vital_signs:alerts")
      Phoenix.PubSub.subscribe(HealthStream.PubSub, "vital_signs:updates")
    end

    socket =
      socket
      |> assign(:patients, get_patients())
      |> assign(:vital_signs, %{})
      |> assign(:alerts, [])
      |> assign(:page_title, "Patient Monitoring Dashboard")

    {:ok, socket}
  end

  @impl true
  def handle_info({:vital_sign_update, vital_sign}, socket) do
    Logger.debug("Received vital sign update for patient #{vital_sign.patient_id}")

    alerts = HealthStream.Monitoring.AnomalyDetector.check_anomalies(vital_sign)

    vital_sign_with_data =
      vital_sign
      |> Map.put(:last_update, DateTime.utc_now())
      |> Map.put(:current_alerts, alerts)

    updated_vital_signs =
      Map.put(socket.assigns.vital_signs, vital_sign.patient_id, vital_sign_with_data)

    socket = assign(socket, :vital_signs, updated_vital_signs)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:vital_sign_alert, vital_sign, alerts}, socket) do
    Logger.warning("Received alert for patient #{vital_sign.patient_id}: #{inspect(alerts)}")

    new_alerts =
      [{vital_sign, alerts, DateTime.utc_now()} | socket.assigns.alerts]
      |> Enum.take(10)

    vital_sign_with_alerts =
      vital_sign
      |> Map.put(:last_update, DateTime.utc_now())
      |> Map.put(:current_alerts, alerts)

    updated_vital_signs =
      Map.put(socket.assigns.vital_signs, vital_sign.patient_id, vital_sign_with_alerts)

    socket =
      socket
      |> assign(:alerts, new_alerts)
      |> assign(:vital_signs, updated_vital_signs)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_patient_mode", %{"patient" => patient_id}, socket) do
    case patient_id do
      "P001" ->
        current_mode = DeviceSimulator.get_mode(:patient_p001)
        new_mode = if current_mode == :normal, do: :critical, else: :normal
        Logger.info("Toggling patient P001 mode to #{new_mode}")
        apply_mode_change(:patient_p001, new_mode)

      "P002" ->
        current_mode = DeviceSimulator.get_mode(:patient_p002)
        new_mode = if current_mode == :normal, do: :critical, else: :normal
        apply_mode_change(:patient_p002, new_mode)

      _ ->
        :ok
    end

    {:noreply, socket}
  end

  defp apply_mode_change(patient_pid, :normal) do
    DeviceSimulator.set_normal_mode(patient_pid)
  end

  defp apply_mode_change(patient_pid, :critical) do
    DeviceSimulator.set_critical_mode(patient_pid)
  end

  defp get_patients do
    [
      %{id: "P001", name: "John Doe", device: "DEV001", mode: :normal},
      %{id: "P002", name: "Jane Smith", device: "DEV002", mode: :normal}
    ]
  end

  defp get_alert_component_class(:critical), do: "alert alert-error"
  defp get_alert_component_class(:alert), do: "alert alert-warning"
  defp get_alert_component_class(_), do: "alert alert-info"

  defp vital_status(patient_id, vital_signs) do
    case Map.get(vital_signs, patient_id) do
      nil -> "No data"
      _vital_sign -> "Monitoring"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-200 p-6">
      <div class="max-w-7xl mx-auto">
        <div class="mb-8">
          <.header>
            🏥 Patient Monitoring Dashboard
            <:subtitle>Real-time vital signs monitoring and alerts</:subtitle>
            <:actions>
              <div class="flex space-x-4 text-sm">
                <.status_indicator color="success">System Online</.status_indicator>
                <.status_indicator color="info">Live Updates Active</.status_indicator>
              </div>
            </:actions>
          </.header>
        </div>

    <!-- Patient Cards -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          <div :for={patient <- @patients} class="card bg-base-100 shadow-lg">
            <div class="card-body">
              <div class="flex justify-between items-start mb-4">
                <div>
                  <h2 class="card-title">{patient.name}</h2>
                  <p class="text-sm opacity-70">ID: {patient.id} | Device: {patient.device}</p>
                  <p class="text-sm opacity-70">Status: {vital_status(patient.id, @vital_signs)}</p>
                  <%= if vital_sign = Map.get(@vital_signs, patient.id) do %>
                    <p class="text-xs opacity-50">
                      Last update: {format_timestamp(Map.get(vital_sign, :last_update))}
                    </p>
                  <% end %>
                </div>
                <div class="card-actions">
                  <.button
                    phx-click="toggle_patient_mode"
                    phx-value-patient={patient.id}
                    variant="primary"
                  >
                    <.icon name="hero-arrow-path" class="size-5" /> Toggle Mode
                  </.button>
                </div>
              </div>

              <%= if vital_sign = Map.get(@vital_signs, patient.id) do %>
                <div class="grid grid-cols-2 gap-4">
                  <div class={"card bg-base-100 border #{get_measurement_card_class(vital_sign, :heart_rate)}"}>
                    <div class="card-body p-3">
                      <div class="text-xs uppercase font-medium opacity-70">Heart Rate</div>
                      <div class="text-xl font-bold">
                        {safe_get_measurement(vital_sign, :heart_rate, "—")}
                        <span class="text-sm font-normal opacity-70">BPM</span>
                      </div>
                      <%= if alert_severity = get_measurement_alert_severity(vital_sign, :heart_rate) do %>
                        <div class="badge badge-error badge-sm font-medium">
                          {String.upcase(to_string(alert_severity))} ALERT
                        </div>
                      <% end %>
                    </div>
                  </div>
                  <div class={"card bg-base-100 border #{get_measurement_card_class(vital_sign, :blood_pressure)}"}>
                    <div class="card-body p-3">
                      <div class="text-xs uppercase font-medium opacity-70">Blood Pressure</div>
                      <div class="text-xl font-bold">
                        {safe_get_measurement(vital_sign, :blood_pressure_sys, "—")}/{safe_get_measurement(
                          vital_sign,
                          :blood_pressure_dia,
                          "—"
                        )}
                        <span class="text-sm font-normal opacity-70">mmHg</span>
                      </div>
                      <%= if alert_severity = get_measurement_alert_severity(vital_sign, :blood_pressure) do %>
                        <div class="badge badge-error badge-sm font-medium">
                          {String.upcase(to_string(alert_severity))} ALERT
                        </div>
                      <% end %>
                    </div>
                  </div>
                  <div class={"card bg-base-100 border #{get_measurement_card_class(vital_sign, :oxygen_saturation)}"}>
                    <div class="card-body p-3">
                      <div class="text-xs uppercase font-medium opacity-70">Oxygen Saturation</div>
                      <div class="text-xl font-bold">
                        {safe_get_measurement(vital_sign, :oxygen_saturation, "—")}<span class="text-sm font-normal opacity-70">%</span>
                      </div>
                      <%= if alert_severity = get_measurement_alert_severity(vital_sign, :oxygen_saturation) do %>
                        <div class="badge badge-error badge-sm font-medium">
                          {String.upcase(to_string(alert_severity))} ALERT
                        </div>
                      <% end %>
                    </div>
                  </div>
                  <div class={"card bg-base-100 border #{get_measurement_card_class(vital_sign, :temperature)}"}>
                    <div class="card-body p-3">
                      <div class="text-xs uppercase font-medium opacity-70">Temperature</div>
                      <div class="text-xl font-bold">
                        {safe_get_measurement(vital_sign, :temperature, "—")}<span class="text-sm font-normal opacity-70">°F</span>
                      </div>
                      <%= if alert_severity = get_measurement_alert_severity(vital_sign, :temperature) do %>
                        <div class="badge badge-error badge-sm font-medium">
                          {String.upcase(to_string(alert_severity))} ALERT
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% else %>
                <div class="text-center py-8 opacity-60">
                  <div class="text-lg">⏳</div>
                  <p class="mt-2">Waiting for vital signs data...</p>
                </div>
              <% end %>
            </div>
          </div>
        </div>

    <!-- Alerts Section -->
        <div class="card bg-base-100 shadow-lg">
          <div class="card-body">
            <h2 class="card-title text-xl mb-4">Recent Alerts</h2>

            <%= if Enum.empty?(@alerts) do %>
              <div class="text-center py-8 opacity-60">
                <p>No alerts at this time</p>
              </div>
            <% else %>
              <div class="space-y-3">
                <div :for={{vital_sign, alerts, timestamp} <- @alerts} class="card bg-base-200 border">
                  <div class="card-body p-4">
                    <div class="flex justify-between items-start mb-2">
                      <h4 class="font-semibold">Patient {vital_sign.patient_id}</h4>
                      <span class="text-sm opacity-70">
                        {format_timestamp(timestamp)}
                      </span>
                    </div>

                    <div class="flex flex-wrap gap-2">
                      <div
                        :for={{type, value, severity} <- alerts}
                        class={get_alert_component_class(severity)}
                      >
                        <.icon name="hero-exclamation-triangle" class="size-4" />
                        <div>
                          <strong>{format_alert_type(type)}:</strong> {format_alert_value(type, value)}
                          <span class="ml-1 font-semibold">
                            ({String.upcase(to_string(severity))})
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </main>
    """
  end

  defp format_alert_type(:heart_rate), do: "Heart Rate"
  defp format_alert_type(:blood_pressure), do: "Blood Pressure"
  defp format_alert_type(:oxygen_saturation), do: "Oxygen Saturation"
  defp format_alert_type(:temperature), do: "Temperature"

  defp format_alert_value(:heart_rate, value), do: "#{value} BPM"
  defp format_alert_value(:blood_pressure, value), do: "#{value} mmHg"
  defp format_alert_value(:oxygen_saturation, value), do: "#{value}%"
  defp format_alert_value(:temperature, value), do: "#{value}°F"

  defp format_timestamp(nil), do: "—"

  defp format_timestamp(timestamp) do
    DateTime.to_string(timestamp)
  end

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

  defp get_measurement_card_class(vital_sign, measurement_type) do
    case get_measurement_alert_severity(vital_sign, measurement_type) do
      :critical -> "border-error bg-error/10"
      :alert -> "border-warning bg-warning/10"
      _ -> "border-base-300"
    end
  end

  defp get_measurement_alert_severity(vital_sign, measurement_type) do
    alerts = Map.get(vital_sign, :current_alerts, [])

    case Enum.find(alerts, fn {type, _value, _severity} -> type == measurement_type end) do
      {_type, _value, severity} -> severity
      nil -> nil
    end
  end
end
