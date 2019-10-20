defmodule Main do

  @nodeLength 8

  def main(numNodes,noOfRequests) do
        #parse_args(args)
        Process.register(self(),:main)
        :ets.new(:hashList, [:set, :protected, :named_table])
        createHashList(numNodes)
        TapestrySupervisor.start_link([numNodes,noOfRequests])
        process(numNodes)
  end

  def createHashList(numNodes) do
    if numNodes==0 do
      :ok
    else
      :ets.insert(:hashList,{Integer.to_string(numNodes),String.slice(Base.encode16(:crypto.hash(:sha, Integer.to_string(numNodes))),0..@nodeLength-1)})
      createHashList(numNodes-1)
    end
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
            
            nextNode = "n"<>elem(Enum.at(:ets.lookup(:hashList,Integer.to_string(x)),0),1)
            GenServer.cast(String.to_atom(nextNode),{:intialize_routing_table,10})
          end

          IO.puts "created all nodes, now sending messages..."

          #goGoGo(numNodes)

      end
      process(numNodes)
  end

end
