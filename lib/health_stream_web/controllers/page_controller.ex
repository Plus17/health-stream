defmodule HealthStreamWeb.PageController do
  use HealthStreamWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
