defmodule RealProductSizeBackendWeb.PageController do
  use RealProductSizeBackendWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
