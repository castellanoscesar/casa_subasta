defmodule AuctionCoordinator do
  def start do
    pid = spawn(fn -> loop(%{next_id: 1, auctions: %{}}) end)
    Process.register(pid, :auction_coordinator)
    pid
  end

  defp loop(state) do
    receive do
      {:create, product, initial_price, duration, caller} ->
        id = state.next_id
        auction = Auction.new(id, product, initial_price, duration)
        pid = AuctionServer.start(auction)

        new_state = %{
          state
          | next_id: id + 1,
            auctions: Map.put(state.auctions, id, pid)
        }

        send(caller, {:ok, id})
        loop(new_state)

      {:find, id, caller} ->
        case Map.get(state.auctions, id) do
          nil ->
            send(caller, {:error, :auction_not_found})
            loop(state)

          pid ->
            send(caller, {:ok, pid})
            loop(state)
        end

      {:list_active, caller} ->
        active =
          state.auctions
          |> Enum.map(fn {id, pid} ->
            send(pid, {:status, self()})

            receive do
              {:status, %Auction{status: :active} = auction} -> {id, auction}
              {:status, _} -> nil
            end
          end)
          # se elimina los nil y quedan las subastas activas
          |> Enum.reject(fn item -> is_nil(item) end)


        send(caller, {:ok, active})
        loop(state)
    end
  end
end
