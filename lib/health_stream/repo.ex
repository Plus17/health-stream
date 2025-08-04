defmodule HealthStream.Repo do
  use Ecto.Repo,
    otp_app: :health_stream,
    adapter: Ecto.Adapters.Postgres
end
