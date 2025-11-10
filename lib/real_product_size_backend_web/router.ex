defmodule RealProductSizeBackendWeb.Router do
  use RealProductSizeBackendWeb, :router

  import RealProductSizeBackendWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RealProductSizeBackendWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_current_user_for_api
  end

  pipeline :public_api do
    plug :accepts, ["json"]
  end

  scope "/", RealProductSizeBackendWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/privacy", PageController, :privacy
    get "/terms", PageController, :terms
    get "/support", PageController, :support
    get "/about", PageController, :about
  end

  # Health check endpoint (public)
  scope "/api", RealProductSizeBackendWeb do
    pipe_through :public_api
    get "/health", HealthController, :health
  end

  # Public API endpoints (no authentication required)
  scope "/api", RealProductSizeBackendWeb.Api do
    pipe_through :public_api

    # Authentication endpoints (public)
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh

    # Demo product endpoints (public - for demo tour)
    get "/products", ProductController, :index
    get "/products/:id", ProductController, :show
    get "/products/categories", ProductController, :categories
    get "/products/brands", ProductController, :brands
    get "/products/stats", ProductController, :stats

    # Content endpoints (public)
    get "/content/privacy", ContentController, :privacy
    get "/content/terms", ContentController, :terms
  end

  # Protected API endpoints (require authentication)
  scope "/api", RealProductSizeBackendWeb.Api do
    pipe_through [:api, RealProductSizeBackendWeb.Plugs.ApiAuth]

    # User profile
    get "/auth/me", AuthController, :me

    # User-specific product endpoints
    post "/products/crawl", ProductController, :crawl
    post "/products/crawl-preview", ProductController, :crawl_preview
    post "/products/confirm", ProductController, :confirm
    post "/products/manual", ProductController, :create_manual
    get "/products/user", ProductController, :user_products
    get "/products/search", ProductController, :search
    get "/products/category/:category", ProductController, :by_category
    get "/products/brand/:brand", ProductController, :by_brand
    get "/products/:id/model", ProductController, :model
    post "/products/:id/generate-model", ProductController, :generate_model

    # Subscription endpoints
    get "/subscriptions/plans", SubscriptionController, :plans
    get "/subscriptions/current", SubscriptionController, :current
    post "/subscriptions/verify", SubscriptionController, :verify

    # Usage tracking endpoints
    post "/usage/track", UsageController, :track
    post "/usage/check", UsageController, :check
    get "/usage/summary", UsageController, :summary

    # Analytics endpoints
    get "/analytics/dashboard", AnalyticsController, :dashboard
    get "/analytics/realtime", AnalyticsController, :realtime
    get "/analytics/user/:user_id", AnalyticsController, :user_analytics
    get "/analytics/time-range", AnalyticsController, :time_range
    get "/analytics/crawling", AnalyticsController, :crawling_metrics
    get "/analytics/platforms", AnalyticsController, :platform_metrics
    get "/analytics/errors", AnalyticsController, :error_metrics

    # Business metrics endpoints
    get "/business-metrics/dashboard", BusinessMetricsController, :dashboard
    get "/business-metrics/user-acquisition", BusinessMetricsController, :user_acquisition
    get "/business-metrics/revenue", BusinessMetricsController, :revenue_analytics
    get "/business-metrics/engagement", BusinessMetricsController, :user_engagement
    get "/business-metrics/subscriptions", BusinessMetricsController, :subscription_analytics
    get "/business-metrics/products", BusinessMetricsController, :product_performance
    get "/business-metrics/realtime", BusinessMetricsController, :realtime_metrics
    get "/analytics/business", AnalyticsController, :business_metrics
    get "/analytics/performance", AnalyticsController, :performance_metrics
    get "/analytics/export", AnalyticsController, :export
    get "/analytics/user-usage", AnalyticsController, :user_usage
    get "/analytics/platform-usage", AnalyticsController, :platform_usage
    get "/analytics/subscriptions", AnalyticsController, :subscription_stats
    get "/analytics/ar-suitability", AnalyticsController, :ar_suitability_stats
    get "/analytics/health", AnalyticsController, :health
    get "/analytics/api-usage", AnalyticsController, :api_usage
  end

  # Other scopes may use custom stacks.
  # scope "/api", RealProductSizeBackendWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:real_product_size_backend, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RealProductSizeBackendWeb.Telemetry
      live "/crawler-test", RealProductSizeBackendWeb.CrawlerTestLive
      live "/tripo-test", RealProductSizeBackendWeb.TripoTestLive
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", RealProductSizeBackendWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", RealProductSizeBackendWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", RealProductSizeBackendWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
