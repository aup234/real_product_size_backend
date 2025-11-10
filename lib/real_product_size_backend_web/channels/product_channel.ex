defmodule RealProductSizeBackendWeb.ProductChannel do
  @moduledoc """
  WebSocket channel for real-time product updates, including 3D model generation status.
  """

  use RealProductSizeBackendWeb, :channel
  require Logger

  @impl true
  def join("product:" <> product_id, _payload, socket) do
    Logger.info("Client joined product channel for product #{product_id}")

    # Store product_id in socket assigns for later use
    socket = assign(socket, :product_id, product_id)

    {:ok, socket}
  end

  @impl true
  def handle_info({:model_generated, model_data}, socket) do
    Logger.info("Broadcasting 3D model completion to product #{socket.assigns.product_id}")

    # Push the model generation completion to the client
    push(socket, "model_ready", %{
      status: "completed",
      model_url: model_data["model_url"],
      product_id: socket.assigns.product_id,
      generated_at: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:model_failed, error_data}, socket) do
    Logger.warning("Broadcasting 3D model failure to product #{socket.assigns.product_id}")

    push(socket, "model_error", %{
      status: "failed",
      error: error_data,
      product_id: socket.assigns.product_id
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:generation_started, data}, socket) do
    Logger.info("Broadcasting 3D model generation start to product #{socket.assigns.product_id}")

    push(socket, "generation_started", %{
      status: "generating",
      product_id: socket.assigns.product_id,
      started_at: data[:started_at] || DateTime.utc_now()
    })

    {:noreply, socket}
  end

  # Handle client requests for status updates
  @impl true
  def handle_in("get_status", _payload, socket) do
    product_id = socket.assigns.product_id

    # You could query the database here for current status
    # For now, just acknowledge the request
    {:reply, {:ok, %{product_id: product_id}}, socket}
  end
end
