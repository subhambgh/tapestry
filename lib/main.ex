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


  def findNeedToKnowNode(selfid,needToKnowNodes,level,[]) do
    {needToKnowNodes,level}
  end

  def findNeedToKnowNode(selfid,needToKnowNodes,level,[head | tail]) do
    {newLevel,_}  = TapestryNode.match(head,selfid)
    {needToKnowNodes,level} =
      cond do
        level==newLevel ->
            findNeedToKnowNode(selfid,needToKnowNodes++[head],level,tail)
        newLevel > level ->
            findNeedToKnowNode(selfid,[head],newLevel,tail)
        true ->
            findNeedToKnowNode(selfid,needToKnowNodes,level,tail)
      end
  end

  def findRootNode(selfid,[],level,rootNode) do
    rootNode
  end

  def findRootNode(selfid,[head|tail],level,rootNode) do
    rootNode = if Kernel.abs(elem(Integer.parse(String.at(selfid,level),16),0)-elem(Integer.parse(String.at(rootNode,level),16),0))>
      Kernel.abs(elem(Integer.parse(String.at(selfid,level),16),0)-elem(Integer.parse(String.at(head,level),16),0)) do
          findRootNode(selfid,tail,level,head)
      else
        findRootNode(selfid,tail,level,rootNode)
      end
  end

  def process(numNodes, noOfRequests) do
      #
      receive do
        {:nodes_created} ->
          hashList = Enum.map 1..numNodes, fn(x) -> elem(Enum.at(:ets.lookup(:hashList,Integer.to_string(x)),0),1) end
          Enum.map hashList,fn x->
            _ = GenServer.call(String.to_atom("n"<>x),{:intialize_routing_table,numNodes})
          end
          newHashList = hashList -- [Enum.at(hashList,numNodes-1)]
          {needToKnowNodes,level} = findNeedToKnowNode(Enum.at(hashList,numNodes-1),[],0,newHashList)
          rootNode = findRootNode(Enum.at(hashList,numNodes-1),needToKnowNodes,level,Enum.at(needToKnowNodes,0))
          #IO.puts "lastNode=#{Enum.at(hashList,numNodes-1)}, needtoKnowNodes=#{inspect needToKnowNodes}, rootNode=#{rootNode}"
          needToKnowNodesFromRoot =  GenServer.call(String.to_atom("n"<>rootNode),{:multicast,level,Enum.at(hashList,numNodes-1),[rootNode]},:infinity)
          backpointerList = Enum.reduce needToKnowNodesFromRoot,[],fn x,acc->
              acc ++ GenServer.call(String.to_atom("n"<>x),{:getBackpointerList})
          end
          #IO.puts "needToKnowNodesFromRoot=#{inspect needToKnowNodesFromRoot}"
          #IO.puts "backpointerList=#{inspect backpointerList}"
          finalRouteTableList = Enum.uniq(needToKnowNodesFromRoot++backpointerList)
          #IO.puts "finalRouteTableList=#{inspect finalRouteTableList}"
          Enum.map finalRouteTableList, fn x ->
              GenServer.cast(String.to_atom("n"<>Enum.at(hashList,numNodes-1)),{:addToRoutTable,x})
          end
          # IO.puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
          # Enum.map hashList, fn x ->
          #   IO.puts "##{x}=#{inspect GenServer.call(String.to_atom("n"<>x),{:getBackpointerList},:infinity)}"
          # end
          # IO.puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
          # Enum.map hashList, fn x ->
          #   GenServer.cast(String.to_atom("n"<>x),{:printRoutTable})
          # end
        goGoGo(numNodes, numNodes, noOfRequests)

      end
      process(numNodes, noOfRequests)
  end

end
