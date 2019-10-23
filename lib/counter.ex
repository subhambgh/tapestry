defmodule Tapestry.Counter do
  @moduledoc """
  A GenServer template for a "singleton" process.
  """
  use GenServer

  # Initialization
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [name: __MODULE__])
  end

  def init([numNodes]) do
    hashList = Enum.map 1..numNodes, fn(x) -> elem(Enum.at(:ets.lookup(:hashList,Integer.to_string(x)),0),1) end
    max = 0
    receiver = ""
    sender = ""
    {:ok, hashList, max, sender, receiver}
  end


  def handle_cast({:okk_done, my_max, me, the_receiver}, {hashList, max,sender,receiver}) do
    if my_max > max do
      max = my_max
      sender = me
      receiver = the_receiver
    end
    new_hashList = hashList --[me]
    if length(new_hashList) == 0 do
      IO.puts "Max Requests is #{my_max}"
    end
    {:noreply, {max,sender,receiver}}
  end



end