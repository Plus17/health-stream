defmodule HealthStream.VitalSignsPipeline do
  @moduledoc """
  Broadway pipeline for processing vital signs from Kafka.
  """

  use Broadway

  alias Broadway.Message
  alias HealthStream.Monitoring
  alias HealthStream.Monitoring.AnomalyDetector

  require Logger

  def start_link(_opts) do
    producer_module =
      Application.fetch_env!(:health_stream, :producer_module)

    producer_options =
      Application.get_env(:health_stream, :producer_options, [])

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {producer_module, producer_options},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 2]
      ]
    )
  end

  @impl Broadway
  def prepare_messages(messages, context) do
    Logger.debug("Preparing #{inspect(messages)} messages with context: #{inspect(context)}")

    messages = Enum.map(messages, fn msg -> Message.update_data(msg, &Jason.decode!/1) end)

    Logger.debug("Prepared messages: #{inspect(messages)}")
    messages
  end

  @impl Broadway
  def handle_message(_, %Message{data: raw_data} = message, _) do
    Logger.debug("Processing vital signs message: #{inspect(raw_data)}")

    with {:ok, vital_sign} <- Monitoring.build_vital_sign(raw_data) do
      alerts = AnomalyDetector.check_anomalies(vital_sign)

      Logger.debug("Anomalies detected: #{inspect(alerts)}")

      if Enum.empty?(alerts) do
        broadcast_vital_sign(vital_sign)
      else
        broadcast_alert(vital_sign, alerts)
      end

      Message.put_data(message, vital_sign)
    else
      {:error, %Jason.DecodeError{}} ->
        Logger.warning("Invalid JSON in vital signs message: #{inspect(raw_data)}")
        Message.failed(message, "invalid_json")

      {:error, changeset} ->
        Logger.warning("Validation error for vital sign: #{inspect(changeset.errors)}")
        Logger.warning("Original message: #{inspect(raw_data)}")
        Message.failed(message, "validation_error")
    end
  end

  defp broadcast_vital_sign(vital_sign) do
    Phoenix.PubSub.broadcast(
      HealthStream.PubSub,
      "vital_signs:updates",
      {:vital_sign_update, vital_sign}
    )
  end

  defp broadcast_alert(vital_sign, alerts) do
    Phoenix.PubSub.broadcast(
      HealthStream.PubSub,
      "vital_signs:alerts",
      {:vital_sign_alert, vital_sign, alerts}
    )
  end
end
