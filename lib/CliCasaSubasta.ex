defmodule CliCasaSubasta do
  def run do
    AuctionCoordinator.start()
    IO.puts("Casa de Subastas - escribí 'ayuda' para ver comandos")
    loop()
  end

  defp loop do
    input = IO.gets("> ") |> String.trim()
    process(input)
    loop()
  end

  def process("salir") do
    IO.puts("Adios!")
    System.halt(0)
  end

  def process("ayuda"), do: IO.puts("Comandos: crear, activas, consultar, ofertar, salir")
  def process("") , do: :ok

  def process("crear " <> rest) do
    case String.split(rest, " ") do
      [product, price_str, duration_str] ->
        product = String.trim(product, "\"")

        with {price, ""} <- Integer.parse(price_str),
            {duration, ""} <- Integer.parse(duration_str) do
          send(:auction_coordinator, {:create, product, price, duration, self()})

          receive do
            {:ok, id} ->
              IO.puts("OK subasta=#{id} producto=\"#{product}\" precio_inicial=#{price} duracion_ms=#{duration}")

            {:error, reason} ->
              IO.puts("ERROR #{reason}")
          end
        else
          _ -> IO.puts("ERROR valores_invalidos")
        end

      _ ->
        IO.puts("ERROR comando_mal_formado")
    end
  end

  def process("activas") do
  send(:auction_coordinator, {:list_active, self()})

  receive do
    {:ok, auctions} ->
      case auctions do
        [] ->
          IO.puts("No hay subastas activas")

        _ ->
          Enum.each(auctions, fn {id, auction} ->
            best =
              case auction.offers do
                [] -> "sin ofertas"
                offers ->
                  max = Enum.max_by(offers, fn o -> o.amount end)
                  "#{max.amount} por #{max.user}"
              end

            IO.puts("#{id} | #{auction.product} | #{best}")
          end)
      end
  end
  end


  def process("consultar " <> id_str) do
  case Integer.parse(id_str) do
    {id, ""} ->
      send(:auction_coordinator, {:find, id, self()})

      receive do
        {:ok, pid} ->
          send(pid, {:status, self()})

          receive do
            {:status, auction} ->
              IO.puts("subasta=#{auction.id} producto=\"#{auction.product}\" estado=#{auction.status} precio_inicial=#{auction.initial_price}")

              case auction.offers do
                [] ->
                  IO.puts("ofertas_aceptadas=0 mayor_oferta=ninguna")

                offers ->
                  max = Enum.max_by(offers, fn o -> o.amount end)
                  IO.puts("ofertas_aceptadas=#{length(offers)} mayor_oferta=#{max.amount} usuario=#{max.user}")
              end

              if auction.status == :closed do
                IO.puts("ganador=#{auction.winner || "ninguno"} precio_final=#{auction.final_price || "ninguno"}")
              end
          end

        {:error, :auction_not_found} ->
          IO.puts("ERROR subasta_inexistente subasta=#{id}")
      end

    _ ->
      IO.puts("ERROR id_invalido")
  end
end

def process("ofertar " <> rest) do
  case String.split(rest, " ") do
    [id_str, user, amount_str] ->
      with {id, ""} <- Integer.parse(id_str),
           {amount, ""} <- Integer.parse(amount_str),
           true <- user != "" do
        send(:auction_coordinator, {:find, id, self()})

        receive do
          {:ok, pid} ->
            send(pid, {:offer, user, amount, self()})

            receive do
              :ok ->
                IO.puts("OK oferta_aceptada subasta=#{id} usuario=#{user} importe=#{amount}")

              {:error, reason} ->
                IO.puts("ERROR #{reason} subasta=#{id}")
            end

          {:error, :auction_not_found} ->
            IO.puts("ERROR subasta_inexistente subasta=#{id}")
        end
      else
        _ -> IO.puts("ERROR valores_invalidos")
      end

    _ ->
      IO.puts("ERROR comando_mal_formado")
  end
end

  def process(_), do: IO.puts("ERROR comando_invalido")

  #para Test
  def exec(input), do: process(input)
end
