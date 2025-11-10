defmodule RealProductSizeBackendWeb.Api.ProductController do
  use RealProductSizeBackendWeb, :controller

  alias RealProductSizeBackend.{
    Products,
    Crawling,
    MockDataService,
    TriPoService,
    UserProducts,
    PlatformCrawler,
    Subscriptions,
    UsageAnalytics,
    ErrorHandler,
    DataAdapter,
    SecurityValidator,
    FileUpload
  }

  require Logger

  @doc """
  Lists products with pagination and filters.
  """
  def index(conn, params) do
    # Demo: Use mock data if configured
    if Application.get_env(:real_product_size_backend, :debug)[:use_mock_product_data] do
      products = MockDataService.list_mock_products(params)
      # Normalize mock data to ensure Flutter compatibility
      normalized_products = Enum.map(products, &DataAdapter.normalize_product_data(&1, :mock))
      render(conn, :index, products: normalized_products)
    else
      # Future: Real database query with pagination, filtering, caching
      products = Products.list_products(params)
      # Normalize database products to Flutter format
      normalized_products = Enum.map(products, &DataAdapter.database_to_flutter_format/1)
      render(conn, :index, products: normalized_products)
    end
  end

  @doc """
  Gets a single product by ID.
  """
  def show(conn, %{"id" => id}) do
    # Demo: Use mock data if configured
    if Application.get_env(:real_product_size_backend, :debug)[:use_mock_product_data] do
      product = MockDataService.get_mock_product(id)
      # Normalize mock data to ensure Flutter compatibility
      normalized_product = DataAdapter.normalize_product_data(product, :mock)
      render(conn, :show, product: normalized_product)
    else
      # Future: Real database query with eager loading, caching
      product = Products.get_product!(id)
      # Normalize database product to Flutter format
      normalized_product = DataAdapter.database_to_flutter_format(product)
      render(conn, :show, product: normalized_product)
    end
  end

  @doc """
  Crawls a product URL and returns preview data without saving to database.
  """
  def crawl_preview(conn, %{"url" => url}) do
    user_id = conn.assigns.current_user.id

    Logger.info("Starting product crawl preview for URL: #{url}")

    # Validate URL for security
    case SecurityValidator.validate_url(url) do
      {:error, reason} ->
        Logger.warning("Invalid URL provided: #{url}, reason: #{reason}")
        conn
        |> put_status(400)
        |> json(%{error: "Invalid URL", reason: reason})

      {:ok, validated_url} ->
        Logger.info("URL validated successfully: #{validated_url}")

        # Check usage limits before crawling
        case Subscriptions.check_usage_limit(user_id, "product_crawl") do
          false ->
            Logger.warning("Usage limit exceeded for user #{user_id}")
            # Get usage summary to show current limits
            usage_summary = Subscriptions.get_usage_summary(user_id)

            conn
            |> put_status(429)
            |> json(%{
              error: "Usage limit exceeded",
              reason: "You have reached your monthly product crawl limit",
              current_usage: usage_summary.product_crawls,
              limit: usage_summary.limits["product_crawls"],
              upgrade_required: true
            })

          true ->
            Logger.info("Usage limit check passed for user #{user_id}")

            # Use the platform crawler for multi-platform support
            case PlatformCrawler.crawl_product(validated_url) do
              {:error, reason} ->
                Logger.error("Platform crawler failed for URL #{url}: #{inspect(reason)}")
                # Handle error with recovery strategies
                context = %{user_id: user_id, url: url}
                case ErrorHandler.handle_crawl_error(url, reason, context) do
                  {:error, error_response} ->
                    # Error could not be recovered, return user-friendly error
                    conn
                    |> put_status(400)
                    |> json(ErrorHandler.create_error_response(error_response, context))
                end

              {:ok, product_data} ->
                Logger.info("Product data extracted successfully for URL #{url}")
                Logger.debug("Extracted product data: #{inspect(product_data)}")

                # Check AR suitability before processing
                if not product_data.ar_suitable do
                  Logger.warning("Product not suitable for AR visualization: #{url}")
                  conn
                  |> put_status(422)
                  |> json(%{error: "Product not suitable for AR visualization", reason: "Digital product, service, or gift card"})
                else
                  Logger.info("Product is AR suitable, returning preview data")

                  # Convert platform-specific data to preview format (without saving to DB)
                  preview_data = convert_to_preview_format(product_data, validated_url)

                  conn
                  |> put_status(200)
                  |> json(%{data: preview_data})
                end
            end
        end
    end
  end

  @doc """
  Crawls an Amazon product URL and creates a product.
  """
  def crawl(conn, %{"url" => url}) do
    user_id = conn.assigns.current_user.id

    # Validate URL for security
    case SecurityValidator.validate_url(url) do
      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid URL", reason: reason})

      {:ok, validated_url} ->
        # Check usage limits before crawling
        case Subscriptions.check_usage_limit(user_id, "product_crawl") do
      false ->
        # Get usage summary to show current limits
        usage_summary = Subscriptions.get_usage_summary(user_id)

        conn
        |> put_status(429)
        |> json(%{
          error: "Usage limit exceeded",
          reason: "You have reached your monthly product crawl limit",
          current_usage: usage_summary.product_crawls,
          limit: usage_summary.limits["product_crawls"],
          upgrade_required: true
        })

      true ->
        # Use the new platform crawler for multi-platform support
        case PlatformCrawler.crawl_product(validated_url) do
          {:error, reason} ->
            # Handle error with recovery strategies
            context = %{user_id: user_id, url: url}
            case ErrorHandler.handle_crawl_error(url, reason, context) do
              {:error, error_response} ->
                # Error could not be recovered, return user-friendly error
                conn
                |> put_status(400)
                |> json(ErrorHandler.create_error_response(error_response, context))
            end

          {:ok, product_data} ->
            # Check AR suitability before processing
            if not product_data.ar_suitable do
              conn
              |> put_status(422)
              |> json(%{error: "Product not suitable for AR visualization", reason: "Digital product, service, or gift card"})
            else
              # Convert platform-specific data to database format
              product_attrs = convert_to_database_format(product_data, validated_url)

              case Products.create_product(product_attrs) do
                {:ok, product} ->
                  # Track usage after successful crawl
                  Subscriptions.track_usage(user_id, "product_crawl")

                  # Track detailed analytics
                  UsageAnalytics.track_product_crawl(
                    user_id,
                    url,
                    product_data.platform,
                    product_data.crawl_quality_score || 0.0,
                    true
                  )

                  # Log the crawl for analytics
                  Crawling.create_crawling_history(%{
                    source_url: url,
                    source_type: to_string(product_data.platform),
                    status: "success",
                    user_id: user_id,
                    product_id: product.id,
                    crawler_config: %{platform: product_data.platform, quality_score: product_data.crawl_quality_score}
                  })

                  # Create user-product association
                  UserProducts.create_user_product(%{
                    user_id: user_id,
                    product_id: product.id
                  })

                  # Set model generation status to pending (no auto-generation)
                  Products.update_product_generation_status(product.id, "pending")

                  # Convert back to Flutter format for response using data adapter
                  flutter_product = DataAdapter.database_to_flutter_format(product)

                  render(conn, :show, product: flutter_product)

                {:error, changeset} ->
                  conn
                  |> put_status(422)
                  |> json(%{error: "Failed to create product", details: changeset.errors})
              end
            end
          end
        end
    end
  end

  @doc """
  Searches products by query.
  """
  def search(conn, %{"q" => query}) do
    # Validate search query for security
    case SecurityValidator.validate_search_query(query) do
      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid search query", reason: reason})

      {:ok, validated_query} ->
        if Application.get_env(:real_product_size_backend, :debug)[:use_mock_product_data] do
          products = MockDataService.search_mock_products(validated_query)
          # Normalize mock data to ensure Flutter compatibility
          normalized_products = Enum.map(products, &DataAdapter.normalize_product_data(&1, :mock))
          render(conn, :index, products: normalized_products)
        else
          # Future: Full-text search with Elasticsearch, relevance scoring, faceted search
          products = Products.search_products(validated_query, conn.params)
          # Normalize database products to Flutter format
          normalized_products = Enum.map(products, &DataAdapter.database_to_flutter_format/1)
          render(conn, :index, products: normalized_products)
        end
    end
  end

  @doc """
  Gets products by category.
  """
  def by_category(conn, %{"category" => category}) do
    if Application.get_env(:real_product_size_backend, :debug)[:use_mock_product_data] do
      products = MockDataService.list_mock_products()
      filtered_products = Enum.filter(products, &(&1.category == category))
      # Normalize mock data to ensure Flutter compatibility
      normalized_products = Enum.map(filtered_products, &DataAdapter.normalize_product_data(&1, :mock))
      render(conn, :index, products: normalized_products)
    else
      products = Products.get_products_by_category(category, conn.params)
      # Normalize database products to Flutter format
      normalized_products = Enum.map(products, &DataAdapter.database_to_flutter_format/1)
      render(conn, :index, products: normalized_products)
    end
  end

  @doc """
  Gets products by brand.
  """
  def by_brand(conn, %{"brand" => brand}) do
    if Application.get_env(:real_product_size_backend, :debug)[:use_mock_product_data] do
      products = MockDataService.list_mock_products()
      filtered_products = Enum.filter(products, &(&1.brand == brand))
      # Normalize mock data to ensure Flutter compatibility
      normalized_products = Enum.map(filtered_products, &DataAdapter.normalize_product_data(&1, :mock))
      render(conn, :index, products: normalized_products)
    else
      products = Products.get_products_by_brand(brand, conn.params)
      # Normalize database products to Flutter format
      normalized_products = Enum.map(products, &DataAdapter.database_to_flutter_format/1)
      render(conn, :index, products: normalized_products)
    end
  end

  @doc """
  Gets product categories.
  """
  def categories(conn, _params) do
    if Application.get_env(:real_product_size_backend, :debug)[:use_mock_product_data] do
      categories = MockDataService.get_mock_categories()
      json(conn, %{categories: categories})
    else
      # Future: Get categories from database
      categories = ["Electronics", "Home & Kitchen", "Sports & Outdoors"]
      json(conn, %{categories: categories})
    end
  end

  @doc """
  Gets product brands.
  """
  def brands(conn, _params) do
    if Application.get_env(:real_product_size_backend, :debug)[:use_mock_product_data] do
      brands = MockDataService.get_mock_brands()
      json(conn, %{brands: brands})
    else
      # Future: Get brands from database
      brands = ["MockBrand", "DemoCorp", "TestInc"]
      json(conn, %{brands: brands})
    end
  end

  @doc """
  Gets product statistics.
  """
  def stats(conn, _params) do
    if Application.get_env(:real_product_size_backend, :debug)[:use_mock_product_data] do
      stats = %{
        total_products: 5,
        verified_products: 5,
        needs_review: 0,
        verification_rate: 1.0
      }

      json(conn, stats)
    else
      stats = Products.get_product_stats()
      json(conn, stats)
    end
  end

  # Private functions

  defp validate_required_field(params, field) do
    case Map.get(params, field) do
      nil -> {:error, "Missing required field: #{field}"}
      "" -> {:error, "Field #{field} cannot be empty"}
      value when is_binary(value) -> {:ok, String.trim(value)}
      _ -> {:error, "Invalid value for field: #{field}"}
    end
  end

  defp validate_dimension_field(params, field) do
    case Map.get(params, field) do
      nil -> {:error, "Missing required field: #{field}"}
      value when is_binary(value) ->
        case Float.parse(value) do
          {float_val, _} when float_val > 0 -> {:ok, float_val}
          _ -> {:error, "Invalid dimension value for #{field}: must be a positive number"}
        end
      value when is_number(value) and value > 0 -> {:ok, value}
      _ -> {:error, "Invalid dimension value for #{field}: must be a positive number"}
    end
  end

  defp validate_image_uploads(conn) do
    # Extract file uploads from multipart form data
    uploads = extract_file_uploads_from_params(conn.params)

    case uploads do
      [] -> {:error, "No valid images uploaded"}
      uploads when length(uploads) > 5 -> {:error, "Too many images: #{length(uploads)} (max 5)"}
      uploads -> {:ok, uploads}
    end
  end

  defp extract_file_uploads_from_params(params) do
    params
    |> Enum.filter(fn {_key, value} ->
      case value do
        %Plug.Upload{} -> true
        _ -> false
      end
    end)
    |> Enum.map(fn {_key, upload} -> upload end)
    |> Enum.filter(fn upload ->
      upload.content_type in ["image/jpeg", "image/jpg", "image/png"]
    end)
  end

  defp convert_to_preview_format(product_data, url) do
    %{
      external_id: product_data.id,
      source_url: url,
      source_type: to_string(product_data.platform),
      title: product_data.title || product_data.name,
      brand: product_data.brand || "Unknown",
      category: product_data.category || "General",
      subcategory: product_data.subcategory || "General",
      length_mm: product_data.dimensionsStructured[:length] || 0.0,
      width_mm: product_data.dimensionsStructured[:width] || 0.0,
      height_mm: product_data.dimensionsStructured[:height] || 0.0,
      weight_g: product_data.weight_g || 100.0,
      price_usd: parse_price(product_data.price),
      currency: product_data.currency || "USD",
      description: product_data.description || "",
      features: product_data.features || [],
      materials: product_data.materials || [],
      colors: product_data.colors || [],
      primary_image_url: List.first(product_data.imageUrls || []),
      image_urls: product_data.imageUrls || [],
      crawled_at: DateTime.utc_now(),
      crawl_quality_score: product_data.crawl_quality_score || 0.0,
      # Preview-specific fields
      model_generation_status: "pending"
    }
  end

  defp convert_to_database_format(product_data, url) do
    %{
      external_id: product_data.id,
      source_url: url,
      source_type: to_string(product_data.platform),
      title: product_data.title || product_data.name,
      brand: product_data.brand || "Unknown",
      category: product_data.category || "General",
      subcategory: product_data.subcategory || "General",
      length_mm: product_data.dimensionsStructured[:length] || 0.0,
      width_mm: product_data.dimensionsStructured[:width] || 0.0,
      height_mm: product_data.dimensionsStructured[:height] || 0.0,
      weight_g: product_data.weight_g || 100.0,
      price_usd: parse_price(product_data.price),
      currency: product_data.currency || "USD",
      description: product_data.description || "",
      features: product_data.features || [],
      materials: product_data.materials || [],
      colors: product_data.colors || [],
      primary_image_url: List.first(product_data.imageUrls || []),
      image_urls: product_data.imageUrls || [],
      crawled_at: DateTime.utc_now(),
      crawl_quality_score: product_data.crawl_quality_score || 0.0
    }
  end

  defp parse_price(price) when is_binary(price) do
    price
    |> String.replace(~r/[^\d.]/, "")
    |> case do
      "" -> 0.0
      price_str ->
        case Float.parse(price_str) do
          {value, _} -> value
          :error -> 0.0
        end
    end
  end

  defp parse_price(_), do: 0.0

  defp parse_dimension_field(value) when is_binary(value) do
    case Float.parse(value) do
      {float_value, _} -> float_value
      :error -> nil
    end
  end

  defp parse_dimension_field(value) when is_number(value), do: value
  defp parse_dimension_field(_), do: nil


  @doc """
  Gets all products crawled by the authenticated user.
  """
  def user_products(conn, _params) do
    # Authentication is handled by ApiAuth plug, user is available in conn.assigns
    user = conn.assigns.current_user

    if is_nil(user) do
      Logger.error("ApiAuth: current_user is nil in user_products")
      conn
      |> put_status(401)
      |> json(%{error: "Authentication failed"})
      |> halt()
    end

    user_id = user.id

    # Debug logging
    Logger.info("User products request for user_id: #{inspect(user_id)}")
    Logger.info("User: #{inspect(user)}")

    # Get user's crawled products with 3D model status
    user_products = UserProducts.list_user_products(user_id)

    # Debug logging
    Logger.info("Found #{length(user_products)} user products")

    # Extract products with preloaded associations and normalize using data adapter
    products =
      user_products
      |> Enum.map(fn up ->
        product = up.product
        # Use data adapter to ensure Flutter compatibility
        DataAdapter.database_to_flutter_format(product)
        |> Map.put(:favorite, up.favorite)
        |> Map.put(:ar_view_count, up.ar_view_count)
        |> Map.put(:last_ar_view_at, up.last_ar_view_at)
      end)

    render(conn, :index, products: products)
  end

  @doc """
  Creates a product from manually uploaded images and dimensions.
  """
  def create_manual(conn, params) do
    user_id = conn.assigns.current_user.id

    # Debug logging
    Logger.info("Manual product creation request for user: #{user_id}")
    Logger.info("Request params: #{inspect(params)}")
    Logger.info("Request files: #{inspect(conn.params |> Enum.filter(fn {_k, v} -> match?(%Plug.Upload{}, v) end))}")

    # Validate required fields
    with {:ok, title} <- validate_required_field(params, "title"),
         {:ok, length_mm} <- validate_dimension_field(params, "length_mm"),
         {:ok, width_mm} <- validate_dimension_field(params, "width_mm"),
         {:ok, height_mm} <- validate_dimension_field(params, "height_mm"),
         {:ok, images} <- validate_image_uploads(conn) do

      # Check usage limits
      case Subscriptions.check_usage_limit(user_id, "product_crawl") do
        false ->
          usage_summary = Subscriptions.get_usage_summary(user_id)
          conn
          |> put_status(429)
          |> json(%{
            error: "Usage limit exceeded",
            reason: "You have reached your monthly product creation limit",
            current_usage: usage_summary.product_crawls,
            limit: usage_summary.limits["product_crawls"],
            upgrade_required: true
          })

        true ->
          # Construct base URL for mobile access (replace localhost with actual IP/host)
          base_url = "#{Atom.to_string(conn.scheme)}://#{conn.host}:#{conn.port}"
          Logger.info("Using base URL for image access: #{base_url}")

          # Save uploaded images and get URLs directly
          case FileUpload.save_multiple_images(images, base_url) do
            {:ok, image_urls} ->
              primary_image_url = List.first(image_urls)

              Logger.info("Generated #{length(image_urls)} image URLs: #{inspect(image_urls)}")
              Logger.info("Primary image URL: #{primary_image_url}")

              # Create product attributes
              product_attrs = %{
                external_id: Ecto.UUID.generate(),
                source_url: "manual",
                source_type: "manual",
                title: title,
                brand: "Manual Entry",
                category: "Manual",
                subcategory: "Manual",
                length_mm: length_mm,
                width_mm: width_mm,
                height_mm: height_mm,
                weight_g: 100.0, # Default weight
                price_usd: 0.0,
                currency: "USD",
                description: params["description"] || "",
                features: [],
                materials: [],
                colors: [],
                primary_image_url: primary_image_url,
                image_urls: image_urls,
                crawled_at: DateTime.utc_now(),
                crawl_quality_score: 1.0, # Manual entries are considered high quality
                dimensions_verified: true
              }

              # Create product
              Logger.info("Creating product with attrs: #{inspect(product_attrs)}")
              case Products.create_product(product_attrs) do
                {:ok, product} ->
                  Logger.info("Product created successfully: #{product.id}")
                  # Track usage
                  Subscriptions.track_usage(user_id, "product_crawl")

                  # Track analytics
                  UsageAnalytics.track_product_crawl(
                    user_id,
                    "manual",
                    :manual,
                    1.0,
                    true
                  )

                  # Create user-product association
                  UserProducts.create_user_product(%{
                    user_id: user_id,
                    product_id: product.id
                  })

                  # Set model generation status to pending (no auto-generation)
                  Products.update_product_generation_status(product.id, "pending")

                  # Convert to Flutter format
                  flutter_product = DataAdapter.database_to_flutter_format(product)

                  render(conn, :show, product: flutter_product)

                {:error, changeset} ->
                  Logger.error("Product creation failed: #{inspect(changeset.errors)}")
                  conn
                  |> put_status(422)
                  |> json(%{error: "Failed to create product", details: "Validation failed", errors: changeset.errors})
              end

            {:error, reason} ->
              Logger.error("Failed to save uploaded images: #{inspect(reason)}")
              conn
              |> put_status(500)
              |> json(%{error: "Failed to process images", details: reason})
          end
      end
    else
      # Handle validation errors
      {:error, {:missing_field, field}} ->
        conn
        |> put_status(422)
        |> json(%{error: "Missing required field", field: field})

      {:error, {:invalid_dimension, field, reason}} ->
        conn
        |> put_status(422)
        |> json(%{error: "Invalid dimension", field: field, reason: reason})

      {:error, {:no_images, _}} ->
        conn
        |> put_status(422)
        |> json(%{error: "No valid images uploaded", details: "Please upload at least one image"})

      error ->
        Logger.error("Unexpected error in manual product creation: #{inspect(error)}")
        conn
        |> put_status(500)
        |> json(%{error: "Internal server error", details: "Unexpected error occurred"})
    end
  end

  @doc """
  Confirms product data and saves to database without triggering 3D generation.
  """
  def confirm(conn, params) do
    user_id = conn.assigns.current_user.id

    Logger.info("Confirming product data for user #{user_id}")
    Logger.debug("Confirmation params: #{inspect(params)}")

    # Validate required fields
    with {:ok, title} <- validate_required_field(params, "title"),
         {:ok, length_mm} <- validate_dimension_field(params, "length_mm"),
         {:ok, width_mm} <- validate_dimension_field(params, "width_mm"),
         {:ok, height_mm} <- validate_dimension_field(params, "height_mm"),
         {:ok, source_url} <- validate_required_field(params, "source_url") do

      # Check usage limits
      case Subscriptions.check_usage_limit(user_id, "product_crawl") do
        false ->
          Logger.warning("Usage limit exceeded for user #{user_id} during confirmation")
          usage_summary = Subscriptions.get_usage_summary(user_id)
          conn
          |> put_status(429)
          |> json(%{
            error: "Usage limit exceeded",
            reason: "You have reached your monthly product creation limit",
            current_usage: usage_summary.product_crawls,
            limit: usage_summary.limits["product_crawls"],
            upgrade_required: true
          })

        true ->
          Logger.info("Usage limit check passed for user #{user_id}")

          # Create product attributes from confirmed data
          product_attrs = %{
            external_id: params["external_id"] || Ecto.UUID.generate(),
            source_url: source_url,
            source_type: params["source_type"] || "confirmed",
            title: title,
            brand: params["brand"] || "Unknown",
            category: params["category"] || "General",
            subcategory: params["subcategory"] || "General",
            length_mm: length_mm,
            width_mm: width_mm,
            height_mm: height_mm,
            weight_g: parse_dimension_field(params["weight_g"]) || 100.0,
            price_usd: parse_price(params["price_usd"]) || 0.0,
            currency: params["currency"] || "USD",
            description: params["description"] || "",
            features: params["features"] || [],
            materials: params["materials"] || [],
            colors: params["colors"] || [],
            primary_image_url: params["primary_image_url"],
            image_urls: params["image_urls"] || [],
            crawled_at: DateTime.utc_now(),
            crawl_quality_score: 1.0, # Confirmed entries are high quality
            dimensions_verified: true,
            model_generation_status: "pending"
          }

          Logger.info("Creating confirmed product with attrs: #{inspect(product_attrs)}")

          case Products.create_product(product_attrs) do
            {:ok, product} ->
              Logger.info("Product confirmed successfully: #{product.id}")

              # Track usage
              Subscriptions.track_usage(user_id, "product_crawl")

              # Track analytics
              UsageAnalytics.track_product_crawl(
                user_id,
                source_url,
                :confirmed,
                1.0,
                true
              )

              # Create user-product association
              UserProducts.create_user_product(%{
                user_id: user_id,
                product_id: product.id
              })

              # Ensure model generation status is pending
              Products.update_product_generation_status(product.id, "pending")

              # Convert to Flutter format
              flutter_product = DataAdapter.database_to_flutter_format(product)

              render(conn, :show, product: flutter_product)

            {:error, changeset} ->
              Logger.error("Product confirmation failed: #{inspect(changeset.errors)}")
              conn
              |> put_status(422)
              |> json(%{error: "Failed to confirm product", details: "Validation failed", errors: changeset.errors})
          end
      end
    else
      {:error, reason} ->
        Logger.warning("Product confirmation validation failed: #{inspect(reason)}")
        conn
        |> put_status(400)
        |> json(%{error: "Validation failed", reason: reason})
    end
  end

  @doc """
  Manually triggers 3D model generation for a product.
  """
  def generate_model(conn, %{"id" => product_id}) do
    user_id = conn.assigns.current_user.id

    Logger.info("Manual 3D model generation requested for product #{product_id} by user #{user_id}")

    # Verify user owns the product
    case UserProducts.get_user_product_by_user_and_product(user_id, product_id) do
      nil ->
        Logger.warning("User #{user_id} attempted to generate model for product #{product_id} they don't own")
        conn
        |> put_status(403)
        |> json(%{error: "Access denied", reason: "You don't have permission to generate models for this product"})

      _user_product ->
        # Get the product
        case Products.get_product!(product_id) do
          nil ->
            Logger.warning("Product #{product_id} not found for model generation")
            conn
            |> put_status(404)
            |> json(%{error: "Product not found"})

          product ->
            Logger.info("Found product #{product_id} for model generation")

            # Check if model generation is already in progress
            case product.model_generation_status do
              "generating" ->
                Logger.info("Model generation already in progress for product #{product_id}")
                conn
                |> put_status(409)
                |> json(%{
                  error: "Model generation already in progress",
                  status: "generating",
                  message: "3D model is currently being generated for this product"
                })

              "completed" ->
                Logger.info("Model already exists for product #{product_id}")
                conn
                |> put_status(409)
                |> json(%{
                  error: "Model already exists",
                  status: "completed",
                  message: "3D model has already been generated for this product"
                })

              "failed" ->
                Logger.info("Retrying model generation for product #{product_id} after previous failure")

              _ ->
                Logger.info("Starting new model generation for product #{product_id}")
            end

            # Trigger 3D model generation
            case TriPoService.generate_3d_model(product_id) do
              {:ok, %{job_id: job_id, status: "queued"}} ->
                Logger.info("3D model generation job #{job_id} queued for product #{product_id}")

                # Update product status
                Products.update_product_generation_status(product_id, "generating")

                conn
                |> put_status(200)
                |> json(%{
                  message: "3D model generation started",
                  job_id: job_id,
                  status: "generating",
                  product_id: product_id
                })

              {:error, :disabled_in_production} ->
                Logger.warning("3D model generation disabled in production for product #{product_id}")
                conn
                |> put_status(503)
                |> json(%{
                  error: "3D model generation disabled",
                  reason: "3D model generation is currently disabled in production"
                })

              {:error, :skipped_for_debug} ->
                Logger.info("3D model generation skipped in debug mode for product #{product_id}")
                conn
                |> put_status(503)
                |> json(%{
                  error: "3D model generation skipped",
                  reason: "3D model generation is disabled in debug mode"
                })

              {:error, :service_disabled} ->
                Logger.warning("TriPo service disabled for product #{product_id}")
                conn
                |> put_status(503)
                |> json(%{
                  error: "3D model generation service unavailable",
                  reason: "The 3D model generation service is currently disabled"
                })

              {:error, reason} ->
                Logger.error("Failed to start 3D model generation for product #{product_id}: #{inspect(reason)}")
                conn
                |> put_status(500)
                |> json(%{
                  error: "Failed to start 3D model generation",
                  reason: "An error occurred while starting the 3D model generation process"
                })
            end
        end
    end
  end

  @doc """
  Serves the 3D model file for a product.
  """
  def model(conn, %{"id" => id}) do
    # Get product to check if model exists
    case Products.get_product!(id) do
      %RealProductSizeBackend.Products.Product{} = product ->
        # Check if model generation is completed
        if product.model_generation_status != "completed" do
          conn
          |> put_status(404)
          |> json(%{error: "Model not available yet", status: product.model_generation_status})
        else
          # Construct model file path
          model_path = Application.get_env(:real_product_size_backend, :tripo)[:model_output_path] ||
                      "priv/static/models/products/#{id}.glb"

          # Check if model file exists
          if File.exists?(model_path) do
            # Serve the GLB file
            conn
            |> put_resp_content_type("model/gltf-binary")
            |> put_resp_header("content-disposition", "inline; filename=\"#{id}.glb\"")
            |> send_file(200, model_path)
          else
            conn
            |> put_status(404)
            |> json(%{error: "Model file not found on disk"})
          end
        end
    end
  end
end
