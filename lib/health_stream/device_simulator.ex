defmodule HealthStream.DeviceSimulator do
  @moduledoc """
  GenServer that simulates medical devices sending vital signs to Kafka.
  Supports normal and critical patient modes for demonstration.
  """

  use GenServer
  require Logger

  @topic "vital-signs"
  @interval_ms 5

  defstruct [:patient_id, :device_id, :mode, :kafka_client]

  @type mode :: :normal | :critical
  @type t :: %__MODULE__{
          patient_id: String.t(),
          device_id: String.t(),
          mode: mode(),
          kafka_client: atom()
        }

  ## Client API

  def start_link(opts) do
    {patient_id, opts} = Keyword.pop!(opts, :patient_id)
    {device_id, opts} = Keyword.pop!(opts, :device_id)

    GenServer.start_link(__MODULE__, {patient_id, device_id}, opts)
  end

  @doc "Switch patient to normal vital signs mode"
  def set_normal_mode(pid) do
    GenServer.cast(pid, {:set_mode, :normal})
  end

  @doc "Switch patient to critical vital signs mode"
  def set_critical_mode(pid) do
    GenServer.cast(pid, {:set_mode, :critical})
  end

  @doc "Get current patient mode"
  def get_mode(pid) do
    GenServer.call(pid, :get_mode)
  end

  ## Server Callbacks

  @impl GenServer
  def init({patient_id, device_id}) do
    # Start Kafka client
    kafka_client_name = :"kafka_client_#{patient_id}_#{device_id}"

    case :brod.start_client([localhost: 9092], kafka_client_name) do
      :ok ->
        # Start producer for the topic
        case :brod.start_producer(kafka_client_name, @topic, []) do
          :ok ->
            state = %__MODULE__{
              patient_id: patient_id,
              device_id: device_id,
              mode: :normal,
              kafka_client: kafka_client_name
            }

            schedule_next_measurement()

            Logger.info("Device simulator started for patient #{patient_id}, device #{device_id}")
            {:ok, state}

          {:error, reason} ->
            Logger.error("Failed to start Kafka producer: #{inspect(reason)}")
            {:stop, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to start Kafka client: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_cast({:set_mode, mode}, state) do
    Logger.info("Patient #{state.patient_id} switched to #{mode} mode")
    {:noreply, %{state | mode: mode}}
  end

  @impl GenServer
  def handle_call(:get_mode, _from, state) do
    {:reply, state.mode, state}
  end

  @impl GenServer
  def handle_info(:generate_measurement, state) do
    # Generate and send vital signs
    vital_signs = generate_vital_signs(state.mode)
    message = create_message(state.patient_id, state.device_id, vital_signs)

    case send_to_kafka(state.kafka_client, message) do
      :ok ->
        Logger.debug("Sent vital signs for patient #{state.patient_id}: #{inspect(vital_signs)}")

      {:error, reason} ->
        Logger.warning("Failed to send vital signs: #{inspect(reason)}")
    end

    schedule_next_measurement()

    {:noreply, state}
  end

  ## Private Functions

  defp schedule_next_measurement do
    Process.send_after(self(), :generate_measurement, @interval_ms)
  end

  defp generate_vital_signs(:normal) do
    %{
      heart_rate: Enum.random(65..85),
      blood_pressure_sys: Enum.random(110..130),
      blood_pressure_dia: Enum.random(70..85),
      oxygen_saturation: Enum.random(96..100),
      # 97.5-99.5°F
      temperature: :rand.uniform() * 2.0 + 97.5
    }
  end

  defp generate_vital_signs(:critical) do
    case Enum.random(1..4) do
      # Tachycardia
      1 ->
        %{
          heart_rate: Enum.random(110..140),
          blood_pressure_sys: Enum.random(110..130),
          blood_pressure_dia: Enum.random(70..85),
          oxygen_saturation: Enum.random(96..100),
          temperature: :rand.uniform() * 2.0 + 97.5
        }

      # Hypertension
      2 ->
        %{
          heart_rate: Enum.random(65..85),
          blood_pressure_sys: Enum.random(150..170),
          blood_pressure_dia: Enum.random(95..110),
          oxygen_saturation: Enum.random(96..100),
          temperature: :rand.uniform() * 2.0 + 97.5
        }

      # Low oxygen
      3 ->
        %{
          heart_rate: Enum.random(75..95),
          blood_pressure_sys: Enum.random(110..130),
          blood_pressure_dia: Enum.random(70..85),
          oxygen_saturation: Enum.random(88..94),
          temperature: :rand.uniform() * 2.0 + 97.5
        }

      # Fever
      4 ->
        %{
          heart_rate: Enum.random(85..105),
          blood_pressure_sys: Enum.random(110..130),
          blood_pressure_dia: Enum.random(70..85),
          oxygen_saturation: Enum.random(96..100),
          # 101-104°F
          temperature: :rand.uniform() * 3.0 + 101.0
        }
    end
  end

  defp create_message(patient_id, device_id, measurements) do
    %{
      patient_id: patient_id,
      device_id: device_id,
      measurements: measurements
    }
    |> Jason.encode!()
  end

  defp send_to_kafka(client, message) do
    partition = 0
    key = ""

    case :brod.produce_sync(client, @topic, partition, key, message) do
      :ok -> :ok
      {:ok, _offset} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
