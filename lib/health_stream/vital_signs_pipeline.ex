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
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwayKafka.Producer, kafka_config()},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 4]
      ]
    )
  end

  @impl Broadway
  def handle_message(_, %Message{data: raw_data} = message, _) do
    Logger.debug("Processing vital signs message: #{inspect(raw_data)}")

    with {:ok, data} <- Jason.decode(raw_data),
         {:ok, vital_sign} <- Monitoring.build_vital_sign(data) do
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

  defp kafka_config do
    [
      hosts: [localhost: 9092],
      group_id: "vital_signs_consumer",
      topics: ["vital-signs"],
      offset_reset_policy: :latest,
      receive_interval: 1000
    ]
  end
end
