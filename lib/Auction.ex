defmodule Auction do
  defstruct [:id,
             :product,
             :initial_price,
             :duration,
             :deadline,
             :status,
             offers: [],
             winner: nil,
             final_price: nil]
end
