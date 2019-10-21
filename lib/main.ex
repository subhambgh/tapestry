defmodule Main do

  @nodeLength 8

  def main(numNodes,noOfRequests) do
        #parse_args(args)
        Process.register(self(),:main)
        :ets.new(:hashList, [:set, :protected, :named_table])
        createHashList(numNodes)
        TapestrySupervisor.start_link([numNodes,noOfRequests])
        process(numNodes, noOfRequests)
  end

  def createHashList(numNodes) do
    if numNodes==0 do
      :ok
    else
      :ets.insert(:hashList,{Integer.to_string(numNodes),String.slice(Base.encode16(:crypto.hash(:sha, Integer.to_string(numNodes))),0..@nodeLength-1)})
      createHashList(numNodes-1)
    end
  end


  def goGoGo(numNodes, sendingTo, numRequests) do
    if sendingTo != 0 do   
      nextNode = "n"<>elem(Enum.at(:ets.lookup(:hashList,Integer.to_string(sendingTo)),0),1)
      GenServer.cast(String.to_atom(nextNode), {:goGoGo, numNodes, numRequests})
      #IO.puts "go go go #{sendingTo}"
      goGoGo(numNodes, sendingTo-1, numRequests)  
    end
  end

  def process(numNodes, noOfRequests) do
      #
      receive do
        {:nodes_created} ->
          # IO.puts("haha")
          # hashList = Enum.map 1..numNodes,
          #   fn(x) ->   
          #     nextNode = "n"<>elem(Enum.at(:ets.lookup(:hashList,Integer.to_string(x)),0),1)
          #     GenServer.cast(String.to_atom(nextNode),{:intialize_routing_table,numNodes})
          #   end

          # IO.puts "created all nodes, now sending messages..."

          goGoGo(numNodes, numNodes, noOfRequests)

      end
      process(numNodes, noOfRequests)
  end

end
