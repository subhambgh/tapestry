defmodule Main do

  def main(args) do
        #parse_args(args)
        Process.register(self(),:main)
        TapestrySupervisor.start_link([10,1])
        #:ets.new(:hashList, [:set, :protected, :named_table])
        #:ets.insert(:hashList, {"doomspork", "Sean", ["Elixir", "Ruby", "Java"]})
        process(10)
  end

  def goGoGo(0) do
  	
  end

  def goGoGO(numNodes) do
  	
  end

  def process(numNodes) do
      #
      receive do
        {:nodes_created} ->
          IO.puts("haha")
          hashList = Enum.map 1..numNodes,
          fn(x) ->
            nextNode = "n"<>String.slice(Base.encode16(:crypto.hash(:sha, Integer.to_string(x))),0..7)
            #IO.inspect(String.to_atom(nextNode))
            GenServer.cast(String.to_atom(nextNode),{:intialize_routing_table,10})
          end

          IO.puts "created all nodes, now sending messages..."

          goGoGo(numNodes)

      end
      process(numNodes)
  end


end
