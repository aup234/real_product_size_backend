defmodule RealProductSizeBackendWeb.UserSessionHTML do
  use RealProductSizeBackendWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:real_product_size_backend, RealProductSizeBackend.Mailer)[:adapter] ==
      Swoosh.Adapters.Local
  end
end
