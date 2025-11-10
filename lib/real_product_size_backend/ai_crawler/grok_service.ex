defmodule RealProductSizeBackend.AiCrawler.GrokService do
  @moduledoc """
  Grok AI service for product data extraction using ExLLM for structured outputs.
  """

  require Logger

  alias RealProductSizeBackend.AiCrawler.Schemas.ProductData

  @doc """
  Parse the raw ReqLLM response into a ProductData struct.
  The response contains a message field with the JSON content.
  """
  def parse_structured_response(response) do
    Logger.info("Parsing Grok response structure")

    # Handle ReqLLM response format
    case response do
      %ReqLLM.Response{message: message, context: context, error: nil} ->
        IO.puts("=== RESPONSE DEBUG ===")
        IO.inspect(response, label: "Full response")

        # Try to extract content from message first, then context
        content = extract_message_content(message)

        # If content is empty, try extracting from context
        content = if content == "" do
          IO.puts("Message extraction failed, trying context...")
          extract_from_context(context)
        else
          content
        end

        Logger.info("Extracted content length: #{String.length(content)} characters")
        Logger.info("Raw content: #{content}")

        # Content should be clean JSON now, just trim whitespace
        final_content = String.trim(content)
        Logger.info("Final content: #{final_content}")

        case Jason.decode(final_content) do
          {:ok, data} ->
            IO.puts("=== SUCCESSFULLY DECODED JSON ===")
            IO.inspect(data)
            IO.puts("=== END SUCCESS ===")
            Logger.info("Successfully decoded JSON")
            # Convert the map to ProductData struct
            changeset = ProductData.changeset(%ProductData{}, data)

            if changeset.valid? do
              {:ok, Map.from_struct(Ecto.Changeset.apply_changes(changeset))}
            else
              Logger.error("Invalid product data: #{inspect(changeset.errors)}")
              Logger.error("Invalid data received: #{inspect(data)}")
              {:error, "Invalid product data structure"}
            end

          {:error, reason} ->
            IO.puts("=== JSON PARSING FAILED ===")
            IO.puts("Error: #{inspect(reason)}")
            IO.puts("Content length: #{String.length(content)}")
            IO.puts("Raw content: #{content}")
            IO.puts("=== END JSON ERROR ===")
            Logger.error("Failed to parse JSON response: #{inspect(reason)}")
            Logger.error("Raw content that failed to parse: #{inspect(content)}")
            {:error, "Invalid JSON response"}
        end

      %ReqLLM.Response{error: error} when error != nil ->
        Logger.error("ReqLLM returned error: #{inspect(error)}")
        {:error, "ReqLLM API error"}

      _ ->
        Logger.warning("Unexpected response format: #{inspect(response)}")
        {:error, "Unexpected response format"}
    end
  end

  @doc """
  Extract content from ReqLLM.Context by getting the last assistant message.
  """
  def extract_from_context(context) do
    IO.puts("=== EXTRACTING FROM CONTEXT ===")
    IO.puts("Context type: #{inspect(context.__struct__)}")

    # Context contains a list of messages, get the last assistant message
    cond do
      # Try to access messages field
      is_map(context) && Map.has_key?(context, :messages) ->
        messages = Map.get(context, :messages, [])
        IO.puts("Found #{length(messages)} messages in context")

        # Get the last message (should be assistant's response)
        case List.last(messages) do
          %{text: text} when is_binary(text) ->
            IO.puts("✅ Extracted text from last message")
            text

          %{content: content} when is_binary(content) ->
            IO.puts("✅ Extracted content from last message")
            content

          message when is_map(message) ->
            # Try Map.get
            text = Map.get(message, :text) || Map.get(message, :content) || ""
            IO.puts("✅ Extracted via Map.get from last message")
            text

          _ ->
            IO.puts("⚠️  Could not extract from last message")
            ""
        end

      true ->
        IO.puts("⚠️  Context doesn't have messages field")
        ""
    end
  end

  @doc """
  Extract text content from ReqLLM.Message struct.
  """
  def extract_message_content(message) do
    IO.puts("=== MESSAGE EXTRACTION ===")
    IO.puts("Message type: #{inspect(message.__struct__)}")
    IO.puts("Message inspect: #{inspect(message)}")

    # ReqLLM.Message has a text field that contains a list of ContentPart structs
    cond do
      # Try text field - it's a list of ContentParts
      is_map(message) && Map.has_key?(message, :text) && is_list(message.text) ->
        IO.puts("✅ Found text field (list of ContentParts)")
        # Extract text from each ContentPart and join
        text = extract_text_from_content_parts(message.text)
        IO.puts("✅ Extracted text: #{String.slice(text, 0, 100)}...")
        text

      # If text is binary (older format?)
      is_map(message) && Map.has_key?(message, :text) && is_binary(message.text) ->
        IO.puts("✅ Extracted text from message.text field (binary)")
        message.text

      # Try content field
      is_map(message) && Map.has_key?(message, :content) ->
        content = message.content
        cond do
          is_list(content) ->
            IO.puts("✅ Found content field (list)")
            extract_text_from_content_parts(content)
          is_binary(content) ->
            IO.puts("✅ Extracted text from message.content field (binary)")
            content
          true ->
            ""
        end

      # Try accessing via Map.get with default
      is_map(message) ->
        text_field = Map.get(message, :text)
        content_field = Map.get(message, :content)

        cond do
          is_list(text_field) -> extract_text_from_content_parts(text_field)
          is_binary(text_field) -> text_field
          is_list(content_field) -> extract_text_from_content_parts(content_field)
          is_binary(content_field) -> content_field
          true -> ""
        end

      # Last resort
      true ->
        IO.puts("⚠️  Could not extract content from message")
        ""
    end
  end

  defp extract_text_from_content_parts(parts) when is_list(parts) do
    IO.puts("=== EXTRACTING FROM CONTENT PARTS ===")
    IO.puts("Number of parts: #{length(parts)}")

    parts
    |> Enum.map(fn part ->
      cond do
        # If it's a ContentPart struct with text field
        is_map(part) && Map.has_key?(part, :text) && is_binary(part.text) ->
          IO.puts("  - Found text in ContentPart")
          part.text

        # If it's a ContentPart with content field
        is_map(part) && Map.has_key?(part, :content) && is_binary(part.content) ->
          IO.puts("  - Found content in ContentPart")
          part.content

        # Try Map.get as fallback
        is_map(part) ->
          text = Map.get(part, :text) || Map.get(part, :content) || ""
          if text != "", do: IO.puts("  - Found text via Map.get")
          text

        # If it's already a string
        is_binary(part) ->
          IO.puts("  - Part is already a string")
          part

        true ->
          IO.puts("  - Unknown part type: #{inspect(part)}")
          ""
      end
    end)
    |> Enum.join("")
  end

  defp extract_text_from_content_parts(part) when is_binary(part), do: part
  defp extract_text_from_content_parts(_), do: ""

  @doc """
  Extract content from ReqLLM message structure (legacy).
  """
  def extract_content_from_message(message) do
    IO.puts("=== MESSAGE DEBUG (LEGACY) ===")
    IO.puts("Message type: #{inspect(message.__struct__)}")
    IO.inspect(message, label: "Full message structure")

    # Try different ways to extract content from ReqLLM.Message
    content = try do
      # Try to convert to string
      to_string(message)
    rescue
      _ -> ""
    end

    IO.puts("Converted content: #{inspect(content)}")
    content
  end

  @doc """
  Extract assistant content from context string representation.
  """
  def extract_assistant_content(context_str) do
    # Find the assistant: part
    assistant_pattern = "assistant:\""

    # Find the start of assistant content (after assistant:")
    case :binary.match(context_str, assistant_pattern) do
      {start_pos, _} ->
        # Start after assistant:"
        content_start = start_pos + byte_size(assistant_pattern)
        remaining = binary_part(context_str, content_start, byte_size(context_str) - content_start)

        # Use a more sophisticated approach to find the end of the JSON
        # We'll look for the pattern that closes the assistant message
        case find_json_end(remaining) do
          {end_pos, _} ->
            # Extract the content
            content_length = end_pos
            <<content::binary-size(content_length), _::binary>> = remaining
            content
          :nomatch ->
            # Fallback: extract until the end
            IO.puts("No JSON end found, using fallback")
            remaining
        end
      :nomatch ->
        ""
    end
  end

  @doc """
  Find the end of JSON content by looking for the closing pattern.
  """
  def find_json_end(remaining) do
    # Look for the pattern "> (closing the assistant message)
    case :binary.match(remaining, "\">") do
      {pos, _} ->
        # Check if this position contains valid JSON up to this point
        json_part = binary_part(remaining, 0, pos)
        if valid_json_structure?(json_part) do
          {pos, 2}
        else
          # If not valid JSON, continue looking
          find_json_end(binary_part(remaining, pos + 2, byte_size(remaining) - pos - 2))
        end
      :nomatch ->
        :nomatch
    end
  end

  @doc """
  Clean up JSON content by finding proper boundaries.
  """
  def cleanup_json_content(content) do
    IO.puts("=== CLEANUP DEBUG ===")
    IO.puts("Original content: #{content}")

    # Simple approach: find the first { and the next } that forms a complete JSON object
    case :binary.match(content, "{") do
      {start_pos, _} ->
        remaining = binary_part(content, start_pos, byte_size(content) - start_pos)

        # Find the position of the first } that could be the end of a JSON object
        case :binary.match(remaining, "}") do
          {end_pos, _} ->
            json_candidate = binary_part(remaining, 0, end_pos + 1)
            IO.puts("JSON candidate: #{json_candidate}")

            # Use the new extraction method to separate JSON from metadata
            {json_part, metadata_part} = extract_first_json_object(json_candidate)

            if json_part != "" && metadata_part != "" do
              IO.puts("Extracted JSON: #{json_part}")
              IO.puts("Metadata: #{metadata_part}")
              json_part
            else
              IO.puts("Could not separate JSON from metadata")
              json_candidate
            end
          :nomatch ->
            content
        end
      :nomatch ->
        content
    end
  end

  @doc """
  Fix incomplete JSON by manually completing it.
  """
  def fix_incomplete_json(content) do
    IO.puts("=== FIXING INCOMPLETE JSON ===")
    IO.puts("Original: #{content}")

    # Look for the pattern where JSON ends and metadata begins
    # Pattern: "...">" (truncated content followed by closing and metadata)
    case Regex.run(~r/(\.\.\.)\">/, content) do
      [match, _] ->
        IO.puts("Found truncation pattern: #{match}")

        # Replace the truncation with proper JSON ending
        # Find where the truncation occurs
        case :binary.match(content, match) do
          {trunc_pos, _} ->
            # Get the content before truncation
            before_trunc = binary_part(content, 0, trunc_pos)

            # Try to complete the JSON by adding missing fields and closing brace
            completed_json = complete_truncated_json(before_trunc)
            IO.puts("Completed JSON: #{completed_json}")
            completed_json
          :nomatch ->
            content
        end
      nil ->
        IO.puts("No truncation pattern found")
        content
    end
  end

  @doc """
  Complete truncated JSON by adding missing closing elements.
  """
  def complete_truncated_json(json_start) do
    # Count open braces and quotes to see what's missing
    open_braces = String.graphemes(json_start) |> Enum.count(&(&1 == "{"))
    close_braces = String.graphemes(json_start) |> Enum.count(&(&1 == "}"))
    open_quotes = String.graphemes(json_start) |> Enum.count(&(&1 == "\""))

    IO.puts("Open braces: #{open_braces}, Close braces: #{close_braces}, Open quotes: #{open_quotes}")

    completed = json_start

    # If we have unclosed braces, add the missing closing brace
    completed = if open_braces > close_braces do
      completed <> "}"
    else
      completed
    end

    # If we have unclosed quotes (odd number), add the missing closing quote
    final_quotes = String.graphemes(completed) |> Enum.count(&(&1 == "\""))
    completed = if rem(final_quotes, 2) == 1 do
      completed <> "\""
    else
      completed
    end

    # Always ensure the JSON object is properly closed
    if String.starts_with?(completed, "{") && !String.ends_with?(completed, "}") do
      ^completed = completed <> "}"
    end

    IO.puts("Completed JSON: #{completed}")
    completed
  end

  @doc """
  Find the end of the actual product JSON (not response metadata).
  """
  def find_product_json_end(json_part) do
    IO.puts("Looking for product JSON end in: #{json_part}")

    # Look for the pattern "...">" which indicates the end of the JSON object
    # before the response metadata starts
    case :binary.match(json_part, "...\">") do
      {pos, _} ->
        IO.puts("Found ...\"> at position #{pos}")
        # The JSON should end at the } before "...">
        json_end = pos - 4  # Position of the } before "..."> (subtract 4 for "..." + ">")
        IO.puts("Calculated JSON end position: #{json_end}")

        # Extract and check the JSON
        json_candidate = binary_part(json_part, 0, json_end + 1)
        IO.puts("JSON candidate: #{json_candidate}")

        # Check if this looks like valid JSON
        if valid_json_structure?(json_candidate) do
          IO.puts("JSON candidate is valid")
          {json_end, 1}
        else
          IO.puts("JSON candidate is not valid, trying different position")
          # Try a different position - maybe the JSON ends earlier
          json_end_alt = pos - 5
          json_candidate_alt = binary_part(json_part, 0, json_end_alt + 1)
          IO.puts("Alternative JSON candidate: #{json_candidate_alt}")

          if valid_json_structure?(json_candidate_alt) do
            {json_end_alt, 1}
          else
            # Last resort - just use the position we found
            {pos - 4, 1}
          end
        end
      :nomatch ->
        IO.puts("No ...\"> pattern found")
        :nomatch
    end
  end

  @doc """
  Find the end of JSON by counting balanced braces.
  """
  def find_balanced_json_end(content) do
    IO.puts("=== BALANCED JSON DEBUG ===")
    IO.puts("Content: #{content}")
    result = find_balanced_json_end(content, 0, 0, 0)
    IO.puts("Result: #{inspect(result)}")
    result
  end

  def find_balanced_json_end(<<>>, _, _, pos), do: {pos - 1, 1}
  def find_balanced_json_end(<<"{", rest::binary>>, open_count, close_count, pos) do
    IO.puts("Found {, open_count: #{open_count + 1}, pos: #{pos + 1}")
    find_balanced_json_end(rest, open_count + 1, close_count, pos + 1)
  end
  def find_balanced_json_end(<<"}", rest::binary>>, open_count, close_count, pos) do
    new_close = close_count + 1
    IO.puts("Found }, open_count: #{open_count}, close_count: #{new_close}, pos: #{pos}")
    if new_close == open_count do
      IO.puts("Found matching closing brace at position #{pos}")
      # Found the matching closing brace
      {pos, 1}
    else
      find_balanced_json_end(rest, open_count, new_close, pos + 1)
    end
  end
  def find_balanced_json_end(<<_, rest::binary>>, open_count, close_count, pos) do
    find_balanced_json_end(rest, open_count, close_count, pos + 1)
  end

  @doc """
  Basic check if the content looks like valid JSON structure.
  """
  def valid_json_structure?(content) do
    trimmed = String.trim(content)

    # Must start with { and end with }
    if String.starts_with?(trimmed, "{") && String.ends_with?(trimmed, "}") do
      # Find the first complete JSON object by counting braces
      {json_object, remaining} = extract_first_json_object(trimmed)

      if json_object != "" && remaining != "" do
        # Check if the remaining content contains only metadata-like content
        # (commas, model names, IDs, etc.) or if it contains actual content
        remaining_clean = String.trim(remaining)

        # If remaining contains only metadata patterns, consider it valid
        metadata_patterns = [",", "model:", "id:", "created:", "object:", "finish_reason:"]

        # Check if remaining consists only of metadata patterns
        metadata_only = Enum.all?(String.graphemes(remaining_clean), fn char ->
          char in [",", ":", " ", "\""] ||
          String.contains?(metadata_patterns |> Enum.join(""), char)
        end)

        if metadata_only do
          # This looks like JSON followed by metadata, which is what we expect
          true
        else
          # There's actual content after the JSON, not valid
          false
        end
      else
        # No clear separation between JSON and metadata
        false
      end
    else
      false
    end
  end

  @doc """
  Extract the first complete JSON object from content that may contain metadata.
  """
  def extract_first_json_object(content) do
    # Find the first { and the corresponding }
    case :binary.match(content, "{") do
      {start_pos, _} ->
        remaining = binary_part(content, start_pos, byte_size(content) - start_pos)

        # Use the balanced JSON end finder to find where the JSON object ends
        case find_balanced_json_end(remaining) do
          {end_pos, _} ->
            json_part = binary_part(remaining, 0, end_pos + 1)
            metadata_part = binary_part(remaining, end_pos + 1, byte_size(remaining) - end_pos - 1)
            {json_part, metadata_part}
          :nomatch ->
            {remaining, ""}
        end
      :nomatch ->
        {"", ""}
    end
  end

  @doc """
  Find all positions of a byte in a binary.
  """
  def find_all_positions(binary, byte) do
    find_all_positions(binary, byte, 0, [])
  end

  def find_all_positions(<<>>, _, _, acc), do: Enum.reverse(acc)
  def find_all_positions(<<byte, rest::binary>>, byte, pos, acc) do
    find_all_positions(rest, byte, pos + 1, [pos | acc])
  end
  def find_all_positions(<<_, rest::binary>>, byte, pos, acc) do
    find_all_positions(rest, byte, pos + 1, acc)
  end

  @doc """
  Find the closing pattern for the context.
  """
  def find_closing_pattern(_remaining, quote_positions) do
    # Instead of looking for quote followed by >, let's find the last quote
    # that properly closes the JSON structure
    last_quote_pos = List.last(quote_positions)

    if last_quote_pos do
      # For now, just return the position of the last quote
      # This is a simple approach - we could improve it to validate JSON structure
      {last_quote_pos, 1}
    else
      nil
    end
  end

  @doc """
  Try multiple methods to extract content from ReqLLM response.
  """
  def try_extract_content(response, context, message) do
    # Method 1: Try to convert response to string
    content1 = try do
      to_string(response)
    rescue
      _ -> ""
    end

    if content1 != "" && String.contains?(content1, "assistant:\"") do
      context_str = inspect(response, limit: :infinity, printable_limit: :infinity)
      extract_assistant_content(context_str)
    else
      # Method 2: Try context directly
      content2 = try do
        to_string(context)
      rescue
        _ -> ""
      end

      if content2 != "" && String.contains?(content2, "assistant:\"") do
        context_str = inspect(context, limit: :infinity, printable_limit: :infinity)
        extract_assistant_content(context_str)
      else
        # Method 3: Try message directly
        content3 = try do
          to_string(message)
        rescue
          _ -> ""
        end

        if content3 != "" do
          content3
        else
          # Method 4: Last resort - use the working string representation
          response_str = inspect(response)
          extract_assistant_content(response_str)
        end
      end
    end
  end

  @doc """
  Try to extract content directly from context messages.
  """
  def extract_from_context_messages(context) do
    IO.puts("=== DIRECT CONTEXT ACCESS DEBUG ===")
    IO.inspect(context, label: "Context structure")

    try do
      # Try different ways to access the content
      cond do
        # Try to access as a map with :messages key
        Map.has_key?(context, :messages) ->
          IO.puts("Context has :messages key")
          messages = Map.get(context, :messages)
          extract_from_messages(messages)

        # Try to access as a map with "messages" key
        Map.has_key?(context, "messages") ->
          IO.puts("Context has \"messages\" key")
          messages = Map.get(context, "messages")
          extract_from_messages(messages)

        # Try to convert the entire context to string
        true ->
          IO.puts("Trying to convert context to string")
          to_string(context)
      end
    rescue
      e ->
        IO.puts("Error in direct access: #{inspect(e)}")
        ""
    end
  end

  @doc """
  Extract content from messages list.
  """
  def extract_from_messages(messages) do
    IO.puts("Messages: #{inspect(messages)}")

    case messages do
      [_ | _] = msg_list ->
        # Get the last message
        last_msg = List.last(msg_list)
        IO.puts("Last message: #{inspect(last_msg)}")

        # Try different content fields
        cond do
          Map.has_key?(last_msg, :content) && is_binary(last_msg.content) ->
            last_msg.content
          Map.has_key?(last_msg, "content") && is_binary(last_msg["content"]) ->
            last_msg["content"]
          Map.has_key?(last_msg, :text) && is_binary(last_msg.text) ->
            last_msg.text
          Map.has_key?(last_msg, "text") && is_binary(last_msg["text"]) ->
            last_msg["text"]
          true ->
            # Try to convert message to string
            try do
              to_string(last_msg)
            rescue
              _ -> ""
            end
        end
      _ ->
        ""
    end
  end

  @max_retries 3

  @doc """
  Extracts product data using Grok AI with structured output.
  """
  def extract_product_data(prompt) do
    RealProductSizeBackend.CircuitBreaker.call_with_circuit_breaker(
      :grok_api,
      fn -> do_grok_extraction(prompt) end,
      fn -> {:error, :service_unavailable} end
    )
  end

  defp do_grok_extraction(prompt) do
    # Try XAI_API_KEY first, then fall back to GROK_API_KEY for compatibility
    api_key = System.get_env("XAI_API_KEY") || System.get_env("GROK_API_KEY")

    if is_nil(api_key) or api_key == "" do
      {:error, {"Grok API key not configured", %{provider: "grok", model: "grok-4-fast-reasoning"}}}
    else
      # Set API key using JidoKeys as suggested by ReqLLM error message
      JidoKeys.put("xai.api_key", api_key)

      IO.puts("=== FULL PROMPT ===")
      IO.puts("Prompt length: #{String.length(prompt)} characters")
      IO.puts("Full prompt:")
      IO.puts(prompt)
      IO.puts("=== END PROMPT ===")

      Logger.info("Grok prompt length: #{String.length(prompt)} characters")

      messages = [
        %{
          role: "user",
          content: prompt
        }
      ]

      debug_info = %{
        raw_request: %{
          messages: messages,
          model: "xai:grok-4-fast-reasoning",
          options: [
            temperature: 0.1,
            max_tokens: 50000,
            top_p: 0.8,
            provider_options: [
              max_completion_tokens: 50000
            ]
          ]
        },
        model: "grok-4-fast-reasoning",
        provider: "grok"
      }

      case ReqLLM.generate_text("xai:grok-4-fast-reasoning", messages, [
        temperature: 0.1,
        max_tokens: 50000,  # Reduce token limit for testing
        top_p: 0.8,
        provider_options: [
          max_completion_tokens: 50000  # Reduce completion tokens
        ]
      ]) do
        {:ok, response} ->
          # Parse the raw JSON response into ProductData struct
          case parse_structured_response(response) do
            {:ok, data} ->
              {:ok, {data, Map.put(debug_info, :raw_response, response)}}
            {:error, reason} ->
              {:error, {reason, Map.put(debug_info, :raw_response, response)}}
          end

        {:error, reason} ->
          Logger.error("Grok extraction failed: #{inspect(reason)}")
          {:error, {"Grok extraction failed: #{inspect(reason)}", debug_info}}
      end
    end
  end

  @doc """
  Test Grok API connectivity with structured output.
  """
  def test_connection do
    test_prompt = "Extract product information from this simple HTML: <html><body><h1>Test Product</h1><span class='price'>$19.99</span><p>Dimensions: 10x5x2 inches</p></body></html>"

    Logger.info("Testing Grok API with simple prompt")
    Logger.info("Test prompt: #{test_prompt}")

    case do_grok_extraction(test_prompt) do
      {:ok, response} ->
        Logger.info("Grok API test successful: #{inspect(response)}")
        {:ok, response}

      {:error, reason} ->
        Logger.error("Grok API test failed: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Get Grok API usage statistics.
  """
  def get_usage_stats do
    %{
      provider: "grok",
      model: "grok-4-fast-reasoning",
      max_retries: @max_retries
    }
  end

  @doc """
  Estimate token usage for cost calculation.
  """
  def estimate_token_usage(prompt) do
    estimated_tokens = byte_size(prompt) / 4

    %{
      input_tokens: round(estimated_tokens),
      output_tokens: 500,
      total_tokens: round(estimated_tokens + 500)
    }
  end

  @doc """
  Calculate estimated cost for Grok API usage.
  """
  def calculate_estimated_cost(prompt) do
    usage = estimate_token_usage(prompt)

    input_cost = usage.input_tokens / 1_000_000 * 3.00
    output_cost = usage.output_tokens / 1_000_000 * 15.00
    total_cost = input_cost + output_cost

    %{
      input_cost: input_cost,
      output_cost: output_cost,
      total_cost: total_cost,
      usage: usage
    }
  end
end
