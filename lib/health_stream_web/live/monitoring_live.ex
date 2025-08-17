defmodule HealthStreamWeb.MonitoringLive do
  use HealthStreamWeb, :live_view

  require Logger

  alias HealthStream.DeviceSimulator

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
      |> assign(:patient_modes, %{"P001" => :normal, "P002" => :normal})
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
    current_mode = Map.get(socket.assigns.patient_modes, patient_id, :normal)
    new_mode = if current_mode == :normal, do: :critical, else: :normal

    case patient_id do
      "P001" ->
        Logger.info("Toggling patient P001 mode to #{new_mode}")
        apply_mode_change(:patient_p001, new_mode)

      "P002" ->
        Logger.info("Toggling patient P002 mode to #{new_mode}")
        apply_mode_change(:patient_p002, new_mode)

      _ ->
        :ok
    end

    updated_modes = Map.put(socket.assigns.patient_modes, patient_id, new_mode)
    socket = assign(socket, :patient_modes, updated_modes)

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
        <section
          class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8"
          aria-label="Patient monitoring cards"
        >
          <.patient_card
            :for={patient <- @patients}
            patient={patient}
            vital_signs={@vital_signs}
            mode={Map.get(@patient_modes, patient.id, :normal)}
          />
        </section>
        
    <!-- Alerts Section -->
        <section aria-label="Recent alerts">
          <div class="card bg-base-100 shadow-lg">
            <div class="card-body">
              <h2 class="card-title text-xl mb-4">Recent Alerts</h2>

              <%= if Enum.empty?(@alerts) do %>
                <div class="text-center py-8 opacity-60" role="status" aria-live="polite">
                  <p>No alerts at this time</p>
                </div>
              <% else %>
                <div class="space-y-3">
                  <.alert_notification
                    :for={{vital_sign, alerts, timestamp} <- @alerts}
                    vital_sign={vital_sign}
                    alerts={alerts}
                    timestamp={timestamp}
                  />
                </div>
              <% end %>
            </div>
          </div>
        </section>
      </div>
    </main>
    """
  end
end
