defmodule HealthStreamWeb.MonitoringLive do
  use HealthStreamWeb, :live_view

  alias HealthStream.DeviceSimulator
  require Logger

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

  defp alert_color(:critical), do: "text-red-600 bg-red-50"
  defp alert_color(:alert), do: "text-orange-600 bg-orange-50"

  defp vital_status(patient_id, vital_signs) do
    case Map.get(vital_signs, patient_id) do
      nil -> "No data"
      _vital_sign -> "Monitoring"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 p-6">
      <div class="max-w-7xl mx-auto">
        <div class="mb-8 bg-white rounded-lg shadow-sm p-6">
          <h1 class="text-4xl font-bold text-gray-900 mb-2">🏥 Patient Monitoring Dashboard</h1>
          <p class="text-lg text-gray-600">Real-time vital signs monitoring and alerts</p>
          <div class="mt-4 flex space-x-4 text-sm">
            <div class="flex items-center">
              <div class="w-3 h-3 bg-green-500 rounded-full mr-2"></div>
              <span>System Online</span>
            </div>
            <div class="flex items-center">
              <div class="w-3 h-3 bg-blue-500 rounded-full mr-2"></div>
              <span>Live Updates Active</span>
            </div>
          </div>
        </div>

    <!-- Patient Cards -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          <div :for={patient <- @patients} class="bg-white rounded-lg shadow-md p-6">
            <div class="flex justify-between items-start mb-4">
              <div>
                <h3 class="text-lg font-semibold text-gray-900">{patient.name}</h3>
                <p class="text-sm text-gray-500">ID: {patient.id} | Device: {patient.device}</p>
                <p class="text-sm text-gray-500">Status: {vital_status(patient.id, @vital_signs)}</p>
                <%= if vital_sign = Map.get(@vital_signs, patient.id) do %>
                  <p class="text-xs text-gray-400">
                    Last update: {format_timestamp(Map.get(vital_sign, :last_update))}
                  </p>
                <% end %>
              </div>
              <button
                phx-click="toggle_patient_mode"
                phx-value-patient={patient.id}
                class="px-4 py-2 bg-blue-500 text-white text-sm font-medium rounded-md hover:bg-blue-600 transition-colors"
              >
                <.icon name="hero-arrow-path" class="size-5" /> Toggle Mode
              </button>
            </div>

            <%= if vital_sign = Map.get(@vital_signs, patient.id) do %>
              <div class="grid grid-cols-2 gap-4">
                <div class={"p-3 rounded border-2 #{get_measurement_card_class(vital_sign, :heart_rate)}"}>
                  <div class="text-xs uppercase font-medium">Heart Rate</div>
                  <div class="text-xl font-bold">
                    {safe_get_measurement(vital_sign, :heart_rate, "—")}
                    <span class="text-sm font-normal opacity-70">BPM</span>
                  </div>
                  <%= if alert_severity = get_measurement_alert_severity(vital_sign, :heart_rate) do %>
                    <div class="text-xs mt-1 font-medium">
                      {String.upcase(to_string(alert_severity))} ALERT
                    </div>
                  <% end %>
                </div>
                <div class={"p-3 rounded border-2 #{get_measurement_card_class(vital_sign, :blood_pressure)}"}>
                  <div class="text-xs uppercase font-medium">Blood Pressure</div>
                  <div class="text-xl font-bold">
                    {safe_get_measurement(vital_sign, :blood_pressure_sys, "—")}/{safe_get_measurement(
                      vital_sign,
                      :blood_pressure_dia,
                      "—"
                    )}
                    <span class="text-sm font-normal opacity-70">mmHg</span>
                  </div>
                  <%= if alert_severity = get_measurement_alert_severity(vital_sign, :blood_pressure) do %>
                    <div class="text-xs mt-1 font-medium">
                      {String.upcase(to_string(alert_severity))} ALERT
                    </div>
                  <% end %>
                </div>
                <div class={"p-3 rounded border-2 #{get_measurement_card_class(vital_sign, :oxygen_saturation)}"}>
                  <div class="text-xs uppercase font-medium">Oxygen Saturation</div>
                  <div class="text-xl font-bold">
                    {safe_get_measurement(vital_sign, :oxygen_saturation, "—")}<span class="text-sm font-normal opacity-70">%</span>
                  </div>
                  <%= if alert_severity = get_measurement_alert_severity(vital_sign, :oxygen_saturation) do %>
                    <div class="text-xs mt-1 font-medium">
                      {String.upcase(to_string(alert_severity))} ALERT
                    </div>
                  <% end %>
                </div>
                <div class={"p-3 rounded border-2 #{get_measurement_card_class(vital_sign, :temperature)}"}>
                  <div class="text-xs uppercase font-medium">Temperature</div>
                  <div class="text-xl font-bold">
                    {safe_get_measurement(vital_sign, :temperature, "—")}<span class="text-sm font-normal opacity-70">°F</span>
                  </div>
                  <%= if alert_severity = get_measurement_alert_severity(vital_sign, :temperature) do %>
                    <div class="text-xs mt-1 font-medium">
                      {String.upcase(to_string(alert_severity))} ALERT
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <div class="text-center py-8 text-gray-500 bg-gray-50 rounded">
                <div class="text-lg">⏳</div>
                <p class="mt-2">Waiting for vital signs data...</p>
              </div>
            <% end %>
          </div>
        </div>

    <!-- Alerts Section -->
        <div class="bg-white rounded-lg shadow-md p-6">
          <h2 class="text-xl font-semibold text-gray-900 mb-4">Recent Alerts</h2>

          <%= if Enum.empty?(@alerts) do %>
            <div class="text-center py-8 text-gray-500">
              <p>No alerts at this time</p>
            </div>
          <% else %>
            <div class="space-y-3">
              <div :for={{vital_sign, alerts, timestamp} <- @alerts} class="border rounded-lg p-4">
                <div class="flex justify-between items-start mb-2">
                  <h4 class="font-semibold text-gray-900">Patient {vital_sign.patient_id}</h4>
                  <span class="text-sm text-gray-500">
                    {Calendar.strftime(timestamp, "%H:%M:%S:")}
                  </span>
                </div>

                <div class="space-y-1">
                  <div
                    :for={{type, value, severity} <- alerts}
                    class={"px-3 py-1 rounded-md text-sm inline-block mr-2 #{alert_color(severity)}"}
                  >
                    <strong>{format_alert_type(type)}:</strong> {format_alert_value(type, value)}
                    <span class="ml-1 font-semibold">({String.upcase(to_string(severity))})</span>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
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

  defp safe_get_measurement(vital_sign, field, default \\ "—") do
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
      :critical -> "bg-red-50 border-red-200 text-red-900"
      :alert -> "bg-orange-50 border-orange-200 text-orange-900"
      _ -> "bg-gray-50 border-gray-200 text-gray-900"
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
