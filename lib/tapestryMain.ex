defmodule Tapestry.Main do
  use GenServer

  def start_link([numNodes, numRequests,numFailed]) do
    GenServer.start_link(__MODULE__, {numNodes, numRequests,numFailed},name: __MODULE__)
  end

  @impl true
  def init({numNodes, numRequests,numFailed}) do
      {:ok, {numNodes, numRequests,numFailed}}
  end

  def goGoGo(numNodes, sendingTo, numRequests) do
    if sendingTo != 0 do
      nextNode = "n" <> elem(Enum.at(:ets.lookup(:hashList, Integer.to_string(sendingTo)), 0), 1)
      GenServer.cast(String.to_atom(nextNode), {:goGoGo, numNodes, numRequests})
      # IO.puts "go go go #{sendingTo}"
      goGoGo(numNodes, sendingTo - 1, numRequests)
    end
  end

  def findNeedToKnowNode(_selfid, needToKnowNodes, level, []) do
    {needToKnowNodes, level}
  end

  def findNeedToKnowNode(selfid, needToKnowNodes, level, [head | tail]) do
    {newLevel, _} = TapestryNode.match(head, selfid)

    {needToKnowNodes, level} =
      cond do
        level == newLevel ->
          findNeedToKnowNode(selfid, needToKnowNodes ++ [head], level, tail)

        newLevel > level ->
          findNeedToKnowNode(selfid, [head], newLevel, tail)

        true ->
          findNeedToKnowNode(selfid, needToKnowNodes, level, tail)
      end
  end

  def findRootNode(_selfid, [], _level, rootNode) do
    rootNode
  end

  def findRootNode(selfid, [head | tail], level, rootNode) do
    if Kernel.abs(
           elem(Integer.parse(String.at(selfid, level), 16), 0) -
             elem(Integer.parse(String.at(rootNode, level), 16), 0)
         ) >
           Kernel.abs(
             elem(Integer.parse(String.at(selfid, level), 16), 0) -
               elem(Integer.parse(String.at(head, level), 16), 0)
           ) do
        findRootNode(selfid, tail, level, head)
      else
        findRootNode(selfid, tail, level, rootNode)
      end
  end

  def handle_call({:createNodes},_from,{numNodes, numRequests,numFailed}) do
      n_list = Enum.to_list(1..numNodes)
      Enum.map n_list, fn x ->
        {:ok,pid} = DynamicSupervisor.start_child(TapestryNodeSupervisor, {TapestryNode, [x, numNodes, numRequests]})
        _ref = Process.monitor(pid)
      end
      {:reply, :ok, {numNodes, numRequests,numFailed}}
  end

  def handle_call({:initRoutingTables,hashList},_from,{numNodes, numRequests,numFailed}) do
        Enum.map(hashList, fn x ->
          _ = GenServer.call(String.to_atom("n" <> x), {:intialize_routing_table, numNodes})
        end)
      {:reply, :ok, {numNodes, numRequests,numFailed}}
   end

   def handle_call({:initLastNode,hashList},_from,{numNodes, numRequests,numFailed}) do
        newHashList = hashList -- [Enum.at(hashList, numNodes - 1)]
        {needToKnowNodes, level} =
          findNeedToKnowNode(Enum.at(hashList, numNodes - 1), [], 0, newHashList)
        rootNode =
          findRootNode(
            Enum.at(hashList, numNodes - 1),
            needToKnowNodes,
            level,
            Enum.at(needToKnowNodes, 0)
          )
        needToKnowNodesFromRoot =
          GenServer.call(String.to_atom("n" <> rootNode),
            {:multicast, level, Enum.at(hashList, numNodes - 1), [rootNode]},:infinity)
        backpointerList =
          Enum.reduce(needToKnowNodesFromRoot, [], fn x, acc ->
            acc ++ GenServer.call(String.to_atom("n" <> x), {:getBackpointerList})
          end)
        finalRouteTableList = Enum.uniq(needToKnowNodesFromRoot ++ backpointerList)
        Enum.map(finalRouteTableList, fn x ->
          GenServer.cast(
            String.to_atom("n" <> Enum.at(hashList, numNodes - 1)),
            {:addToRoutTable, x}
          )
        end)
    {:reply, :ok, {numNodes, numRequests,numFailed}}
  end

  def handle_call({:failNodesInit,hashList},_from,{numNodes, numRequests,numFailed}) do
        randomNodesToFail = Enum.take_random(hashList, numFailed)
        Enum.map randomNodesToFail, fn nodeBeingRemoved ->
          #inform x's backpointers of its exit
          backpointerListOfX = GenServer.call(String.to_atom("n" <> nodeBeingRemoved), {:getBackpointerList},:infinity)
          Enum.map backpointerListOfX, fn backPointerOfX ->
            GenServer.call(String.to_atom("n" <> backPointerOfX), {:removeFromRoutTable,nodeBeingRemoved},:infinity)
          end
        end
    {:reply, randomNodesToFail, {numNodes, numRequests,numFailed}}
  end

  def handle_call({:killNodes,randomNodesToFail},_from,{numNodes, numRequests,numFailed}) do
      Enum.map randomNodesToFail, fn nodeBeingRemoved->
        Process.exit(Process.whereis(String.to_atom("n"<>nodeBeingRemoved)), :brutal_kill)
      end
      {:reply, :ok, {numNodes, numRequests,numFailed}}
  end

  def handle_call({:startMessaging},_from,{numNodes, numRequests,numFailed}) do
      goGoGo(numNodes, 1, numRequests)
    {:reply, :ok, {numNodes, numRequests,numFailed}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

end
