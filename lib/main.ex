defmodule Main do

  def main(args) do
        #parse_args(args)
        Process.register(self(),:main)
        TapestrySupervisor.start_link([10,1])
        :ets.new(:hashList, [:set, :protected, :named_table])
        :ets.insert(:hashList, {"doomspork", "Sean", ["Elixir", "Ruby", "Java"]})
        process(10)
  end

  def process(numNodes) do
      receive do
        {:nodes_created} ->
          hashList = Enum.map 1..numNodes,
          fn(x) ->
            nextNode = "n"<>String.slice(Base.encode16(:crypto.hash(:sha, Integer.to_string(x))),0..numNodes-1)
            GenServer.cast(String.to_atom(nextNode),{:intialize_routing_table,10})
          end

      end
      process(numNodes)
  end


end
