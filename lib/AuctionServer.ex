### API del server
defmodule AuctionServer do

def start(%Auction{} = auction) do
  spawn(fn ->
    server_pid = self()
    spawn(fn ->
      Process.sleep(auction.duration)
      send(server_pid, :close)
    end)
    loop(auction)
  end)
end


defp loop(%Auction{} = auction) do
  receive do
    :close ->
      {:ok, new_auction} = Auction.close(auction)
      loop(new_auction)
  end
end

end
