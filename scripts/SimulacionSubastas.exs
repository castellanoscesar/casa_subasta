AuctionCoordinator.start()

defmodule SimulacionSubastas do
  def collect_results(0), do: []

  def collect_results(n) do
    receive do
      {:user_done, user, resultados} ->
        [{user, resultados} | collect_results(n - 1)]
    after
      10_000 -> raise "timeout esperando usuarios"
    end
  end
end

# Semilla
seed =
  case System.argv() do
    [s] -> String.to_integer(s)
    _ -> :os.system_time(:millisecond) |> rem(1_000_000)
  end

:rand.seed(:exsss, {seed, seed, seed})
IO.puts("Semilla: #{seed}")

# Crear subastas
subastas = [
  {"Teclado", 1000, 4000},
  {"Monitor", 5000, 4000},
  {"Mouse", 500, 4000}
]

ids =
  Enum.map(subastas, fn {product, price, duration} ->
    send(:auction_coordinator, {:create, product, price, duration, self()})

    receive do
      {:ok, id} -> id
    end
  end)

IO.puts("Subastas creadas: #{inspect(ids)}")

# Lanzar 100 usuarios
parent = self()
for n <- 1..100 do
  spawn(fn ->
    # Consultar activas
    send(:auction_coordinator, {:list_active, self()})
    receive do
      {:ok, _activas} -> :ok
    end

    # Determinar comportamiento según el usuario
    comportamiento =
      cond do
        rem(n, 10) == 0 -> :late        # 10 usuarios ofertan después del cierre
        rem(n, 3) == 0 -> :equal       # algunos ofertan igual
        rem(n, 3) == 1 -> :low         # algunos ofertan bajo
        true -> :normal                # el resto normal
      end

    # Si es late, esperar a que venza
    if comportamiento == :late do
      Process.sleep(4500)
    end

    resultados =
      for _ <- 1..2 do
        id = Enum.random(ids)
        user = "user#{n}"

        amount =
          case comportamiento do
            :low -> Enum.random([100, 200, 300])
            :equal -> 2000
            :late -> Enum.random([5000, 10000])
            :normal -> Enum.random([1000, 1500, 2000, 2500, 3000])
          end

        send(:auction_coordinator, {:find, id, self()})

        pid =
          receive do
            {:ok, pid} -> pid
          end

        send(pid, {:offer, user, amount, self()})

        receive do
          :ok -> {:accepted, id, amount}
          {:error, reason} -> {:rejected, id, amount, reason}
        end
      end

    send(parent, {:user_done, n, resultados})
  end)
end


# Recolectar resultados
resultados_totales = SimulacionSubastas.collect_results(100)

# Esperar cierre automático (duración + margen)
Process.sleep(4500)

# Verificar cada subasta
IO.puts("\n=== RESULTADOS FINALES ===")

verificaciones =
  Enum.map(ids, fn id ->
    send(:auction_coordinator, {:find, id, self()})

    pid =
      receive do
        {:ok, pid} -> pid
      end

    send(pid, {:status, self()})

    auction =
      receive do
        {:status, a} -> a
      end

    # Ofertas aceptadas de esta subasta en los resultados
    aceptadas =
      resultados_totales
      |> Enum.flat_map(fn {_n, rs} -> rs end)
      |> Enum.filter(fn r ->
        case r do
          {:accepted, auction_id, _} -> auction_id == id
          _ -> false
        end
      end)

    ganador_ok =
      case aceptadas do
        [] -> auction.winner == nil
        _ ->
          max = aceptadas |> Enum.map(fn {:accepted, _, amt} -> amt end) |> Enum.max()
          auction.final_price == max
      end

    IO.puts("#{auction.product}: estado=#{auction.status} ganador=#{auction.winner} precio_final=#{auction.final_price} ofertas_aceptadas=#{length(auction.offers)}")

    ganador_ok
  end)

# Resumen
todas = Enum.flat_map(resultados_totales, fn {_n, rs} -> rs end)
rechazadas_por_motivo =
  todas
  |> Enum.filter(fn r -> match?({:rejected, _, _, _}, r) end)
  |> Enum.group_by(fn {:rejected, _, _, reason} -> reason end)
  |> Enum.map(fn {reason, lista} -> "#{reason}: #{length(lista)}" end)

aceptadas = Enum.count(todas, fn r -> match?({:accepted, _, _}, r) end)
rechazadas = Enum.count(todas, fn r -> match?({:rejected, _, _, _}, r) end)

IO.puts("\n=== RESUMEN ===")
IO.puts("Usuarios: 100")
IO.puts("Solicitudes: #{length(todas)}")
IO.puts("Ofertas aceptadas: #{aceptadas}")
IO.puts("Ofertas rechazadas: #{rechazadas}")

Enum.each(rechazadas_por_motivo, fn m -> IO.puts("  #{m}") end)


if Enum.all?(verificaciones) do
  IO.puts("Verificación: EXITOSA")
else
  IO.puts("Verificación: FALLIDA")
end
