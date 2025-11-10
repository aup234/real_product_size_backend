defmodule RealProductSizeBackendWeb.PageController do
  use RealProductSizeBackendWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def privacy(conn, _params) do
    render(conn, :privacy)
  end

  def terms(conn, _params) do
    render(conn, :terms)
  end

  def support(conn, _params) do
    render(conn, :support)
  end

  def about(conn, _params) do
    render(conn, :about)
  end
end
