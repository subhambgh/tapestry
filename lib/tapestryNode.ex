defmodule TapestryNode do
  use GenServer, restart: :temporary

  @nodeLength 8

  def start_link([x, num_created, numRequests]) do
    [{_, nodeid}] = :ets.lookup(:hashList, Integer.to_string(x))

    GenServer.start_link(__MODULE__, {nodeid, num_created, numRequests},
      name: String.to_atom("n#{nodeid}")
    )
  end

  def init({selfid, _num_created, numRequests}) do
      routetable = Matrix.from_list([[],[],[],[],[],[],[],[]])
      backupRoutetable1 = Matrix.from_list([[],[],[],[],[],[],[],[]])
      backupRoutetable2 = Matrix.from_list([[],[],[],[],[],[],[],[]])
    # {n request completed, max hops, req. for which sender node}
    {:ok, {selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {0, 0, "noOneYet"}, []}}
  end

  def add_self(selfid, routetable, current_level) do
    if current_level == 9 do
      routetable
    else
      # IO.puts "adding #{current_level}"
      {column, _} = Integer.parse(String.at(selfid, current_level - 1), 16)
      routetablenew = put_in(routetable[current_level - 1][column], selfid)
      add_self(selfid, routetablenew, current_level + 1)
    end
  end

  def match(nodeid, selfid) do
    index =
      Enum.find_index(0..(@nodeLength - 1), fn i ->
        String.at(nodeid, i) != String.at(selfid, i)
      end)
    case index do
      0 ->
        {0, elem(Integer.parse(String.at(nodeid, 0), 16), 0)}

      # equal i.e.,nodeid == selfid
      # nil ->
      #   {length-1,elem(Integer.parse(String.at(nodeid,length-1),16),0)}
      _ ->
        {index, elem(Integer.parse(String.at(nodeid, index), 16), 0)}
    end
  end

  def special_case(level, _selfid, routetable) do
    IO.puts("special_case #{routetable[level][0]}")
  end

  def anotherMatch(nodeid, selfid, routetable) do
    index = Enum.find_index(0..7, fn i -> String.at(nodeid, i) != String.at(selfid, i) end)
    {level, slot} =
      case index do
        0 ->
          {0, elem(Integer.parse(String.at(nodeid, 0), 16), 0)}

        _ ->
          {index, elem(Integer.parse(String.at(nodeid, index), 16), 0)}
      end
    if routetable[level][slot] == selfid do
      special_case(level, selfid, routetable)
    else
      {level, slot}
    end
  end

  def closer(selfid, prevNeigh, newNeigh) do
    {level, _} = match(prevNeigh, newNeigh)
    if Kernel.abs(
         elem(Integer.parse(String.at(selfid, level), 16), 0) -
           elem(Integer.parse(String.at(prevNeigh, level), 16), 0)
       ) -
         Kernel.abs(
           elem(Integer.parse(String.at(selfid, level), 16), 0) -
             elem(Integer.parse(String.at(newNeigh, level), 16), 0)
         ) > 0 do
      newNeigh
    else
      prevNeigh
    end
  end

  def routeTableBuilder(routetable, [], _selfid) do
    routetable
  end

  def routeTableBuilder(routetable, [head | tail], selfid) do
    {level, slot} = match(head, selfid)
    newroute =
      if routetable[level][slot] != nil do
        closerNode = closer(selfid, routetable[level][slot], head)
        #more than one node that fits into a cell - store it as backup
        if closerNode == head do
          #when old node is replaced with the new node
          #store the old in backup
          GenServer.cast(self(),{:addtoBackupRoutTable1,routetable[level][slot],level,slot})
          GenServer.cast(String.to_atom("n" <> routetable[level][slot]), {:removeAsBackpointer,selfid })
          GenServer.cast(String.to_atom("n" <> closerNode), {:addAsBackpointer, selfid})
        else
          # when old is gold/closer
          # store new as backup
          GenServer.cast(self(),{:addtoBackupRoutTable1,head,level,slot})
        end
        put_in(routetable[level][slot], closerNode)
      else
        GenServer.cast(String.to_atom("n" <> head), {:addAsBackpointer, selfid})
        put_in(routetable[level][slot], head)
      end
    routeTableBuilder(newroute, tail, selfid)
  end

  def selectNodeToSend(selfid, listOfNodes) do
    x = Enum.random(listOfNodes)
    someNode = "n" <> elem(Enum.at(:ets.lookup(:hashList, Integer.to_string(x)), 0), 1)
    # IO.inspect someNode
    if someNode == selfid do
      # IO.puts("here")
      new_listOfNodes = listOfNodes -- [x]
      selectNodeToSend(selfid, new_listOfNodes)
    else
      someNode
    end
  end

  def route_throught_the_table(routetable, selfid, to_send) do
    {level, slot} = match(selfid, to_send)
    cond do
      routetable[level][slot] == to_send ->
        routetable[level][slot]
      true ->
        nil
    end
  end

  def handle_call({:printTables},_from,{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}) do
    # IO.puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    # IO.puts("#{selfid}=#{inspect(routetable)}")
    # IO.puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    # IO.puts("#{selfid}=#{inspect(backupRoutetable1)}")
    # IO.puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    # IO.puts("#{selfid}=#{inspect(backupRoutetable2)}")
    {:reply,[],{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}}
  end

  def handle_call({:getBackpointerList},_from,{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}) do
    {:reply, backpointerList,{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}}
  end

  def handle_call({:intialize_routing_table, num_created},_from,{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests2, zzzz, backpointerList}) do
    hashList =
      Enum.map(1..num_created, fn x ->
        elem(Enum.at(:ets.lookup(:hashList, Integer.to_string(x)), 0), 1)
      end)
    # eliminating last Node to be added to the routing table of anyNodes
    # this is now done via multicast
    newHashList = (hashList -- [selfid]) -- [Enum.at(hashList, num_created - 1)]
    # last Node has to be initialized dynamically
    routetable =
      if selfid != Enum.at(hashList, num_created - 1) do
        routeTableBuilder(routetable, newHashList, selfid)
      else
        routetable
      end
    routetable = add_self(selfid, routetable, 1)
    {:reply, :ok, {selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests2, zzzz, backpointerList}}
  end

  def handle_cast({:addToRoutTable, newNodeId},{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}) do
    {level, slot} = match(newNodeId, selfid)
    newrouteTable =
      if routetable[level][slot] != nil do
        closerNode = closer(selfid, routetable[level][slot], newNodeId)
        #more than one node that fits into a cell - store it as backup
        if closerNode == newNodeId do
          #when old node is replaced with the new node
          #store the old in backup
          GenServer.cast(self(),{:addtoBackupRoutTable1,routetable[level][slot],level,slot})
          GenServer.cast(String.to_atom("n" <> routetable[level][slot]), {:removeAsBackpointer,selfid })
          GenServer.cast(String.to_atom("n" <> closerNode), {:addAsBackpointer, selfid})
        else
          # when old is gold/closer
          # store new as backup
          GenServer.cast(self(),{:addtoBackupRoutTable1,newNodeId,level,slot})
        end
        put_in(routetable[level][slot], closerNode)
      else
        GenServer.cast(String.to_atom("n" <> newNodeId), {:addAsBackpointer, selfid})
        put_in(routetable[level][slot], newNodeId)
      end
    {:noreply,{selfid, newrouteTable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}}
  end

  def handle_cast({:addAsBackpointer, nodeid},{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}) do
    backpointerList = if !Enum.member?(backpointerList,nodeid) do
      backpointerList ++ [nodeid]
    else
      backpointerList
    end
    {:noreply,{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}}
  end

  def handle_cast({:removeAsBackpointer, nodeid},{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}) do
      backpointerList = backpointerList -- [nodeid]
    {:noreply,{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}}
  end

  def handle_call({:removeFromRoutTable, nodeid},_from,{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}) do
      {level, slot} = match(nodeid, selfid)
      backpointerList = backpointerList -- [nodeid]
      {routetable,backupRoutetable1,backupRoutetable2}=
      cond do
          routetable[level][slot] == nodeid ->
            routetable = put_in routetable[level][slot],nil
            #routetable = put_in routetable[level][slot],backupRoutetable1[level][slot]
            # backupRoutetable1 = put_in backupRoutetable1[level][slot],backupRoutetable2[level][slot]
            # backupRoutetable2 = put_in backupRoutetable2[level][slot],nil
            #IO.puts "##{level},#{slot}=#{inspect routetable}"
            {routetable,backupRoutetable1,backupRoutetable2}
          backupRoutetable1[level][slot] == nodeid ->
            backupRoutetable1 = put_in backupRoutetable1[level][slot],nil
            #backupRoutetable1 = put_in backupRoutetable1[level][slot],backupRoutetable2[level][slot]
            # backupRoutetable2 = put_in backupRoutetable2[level][slot],nil
            {routetable,backupRoutetable1,backupRoutetable2}
          backupRoutetable2[level][slot] == nodeid ->
            backupRoutetable2 = put_in backupRoutetable2[level][slot],nil
            {routetable,backupRoutetable1,backupRoutetable2}
          #true -> {routetable,backupRoutetable1,backupRoutetable2}
      end
      {:reply,[],{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}}
  end

  def handle_cast({:goGoGo, numNodes, numRequests},{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests2, zzzz, backpointerList}) do
    # IO.inspect(selfid)
    if numRequests != 0 do
      listOfNodes = Enum.map(1..numNodes, fn n -> n end)
      # IO.inspect(listOfNodes)
      to_send = selectNodeToSend("n" <> selfid, listOfNodes)
      {level, slot} = anotherMatch(String.slice(to_send, 1..10), selfid, routetable)
      my_closest_connection = cond do
                                routetable[level][slot] != nil ->
                                  routetable[level][slot]
                                backupRoutetable1[level][slot] != nil ->
                                  backupRoutetable1[level][slot]
                                true -> backupRoutetable2[level][slot]
                              end
      # IO.puts "#{selfid} - #{String.slice(to_send, 1..100)} || #{level} #{slot}"
      if my_closest_connection == selfid do
        IO.puts("Sending self")
      end
      GenServer.cast(
        String.to_atom("n" <> my_closest_connection),
        {:routing, numNodes, numRequests, 1, "n" <> selfid, to_send, [my_closest_connection]}
      )
      GenServer.cast(self(), {:goGoGo, numNodes, numRequests - 1})
    end
    {:noreply, {selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests2, zzzz, backpointerList}}
  end

  def handle_call(
        {:multicast, level, newNodeId, prevTargets},
        _from,
        {selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}
      ) do
    targets =
      Enum.uniq(
        Enum.reduce(level..(@nodeLength - 1), [], fn x, acc ->
          acc ++ Matrix.to_list(routetable[x])
        end)
      )
    results =
      Enum.uniq(
        Enum.reduce(targets -- prevTargets, [], fn target, acc ->
          acc ++
            GenServer.call(
              String.to_atom("n" <> target),
              {:multicast, level + 1, newNodeId, Enum.uniq(targets ++ prevTargets)},
              :infinity
            )
        end)
      )
    GenServer.cast(self(), {:addToRoutTable, newNodeId})
    {:reply, Enum.uniq(results ++ targets),
    {selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}}
  end

  def handle_cast({:addtoBackupRoutTable1, nodeid,level,slot},{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}) do
    newbackuprouteTable1 =
      if backupRoutetable1[level][slot] != nil do
        closerNode = closer(selfid, backupRoutetable1[level][slot], nodeid)
        #more than one node that fits into a cell - store it as backup
        if closerNode == nodeid do
          #when old node is replaced with the new node
          #store the old in backup
          GenServer.cast(self(),{:addtoBackupRoutTable2,backupRoutetable1[level][slot],level,slot})
          GenServer.cast(String.to_atom("n" <> backupRoutetable1[level][slot]), {:removeAsBackpointer,selfid })
          GenServer.cast(String.to_atom("n" <> closerNode), {:addAsBackpointer, selfid})
        else
          # when old is gold/closer
          # store new as backup
          GenServer.cast(self(),{:addtoBackupRoutTable2,nodeid,level,slot})
        end
        put_in(backupRoutetable1[level][slot], closerNode)
      else
        GenServer.cast(String.to_atom("n" <> nodeid), {:addAsBackpointer, selfid})
        put_in(backupRoutetable1[level][slot], nodeid)
      end
    {:noreply,{selfid, routetable,newbackuprouteTable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}}
  end

  def handle_cast({:addtoBackupRoutTable2, nodeid,level,slot},{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}) do
    newbackuprouteTable2 =
      if backupRoutetable2[level][slot] != nil do
        closerNode = closer(selfid, backupRoutetable2[level][slot], nodeid)
        if closerNode == nodeid do
          GenServer.cast(String.to_atom("n" <> backupRoutetable2[level][slot]), {:removeAsBackpointer, selfid})
        end
        GenServer.cast(String.to_atom("n" <> closerNode), {:addAsBackpointer, selfid})
        put_in(backupRoutetable2[level][slot], closerNode)
      else
        GenServer.cast(String.to_atom("n" <> nodeid), {:addAsBackpointer, selfid})
        put_in(backupRoutetable2[level][slot], nodeid)
      end
    {:noreply,{selfid, routetable,backupRoutetable1,newbackuprouteTable2, numRequests, {reqCompleted, prevhops, highest}, backpointerList}}
  end

  def handle_cast({:message_received, hops, receiverId, list_traverse},{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, myMaxHops, highestReceiver},backpointerList}) do
    # IO.puts("hops #{hops} #{receiverId}")
    {myMaxHops, highestReceiver} =
      if hops > myMaxHops do
        {hops, receiverId}
      else
        {myMaxHops, highestReceiver}
      end
      IO.inspect routetable
      IO.puts "There you go... #{inspect list_traverse}"

    reqCompleted = reqCompleted + 1
    # IO.puts "#{myMaxHops} #{highestReceiver} #{reqCompleted}"
    # IO.puts "#{selfid} #{receiverId} #{reqCompleted}"
    if reqCompleted == numRequests do
      # GenServer.cast(Process.whereis(:main), {:})
      IO.puts("max for #{selfid} is #{myMaxHops} to #{String.slice(highestReceiver, 1..10)}")
      GenServer.cast(Tapestry.Counter, {:okk_done, myMaxHops, selfid, highestReceiver})
    end
    {:noreply,{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, {reqCompleted, myMaxHops, highestReceiver},backpointerList}}
  end

  def handle_cast({:routing, numNodes, numRequests2, hops, senderId, receiverId, list_traverse},{selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, zzzz, backpointerList}) do
    # IO.puts "#{senderId} --> #{receiverId} || #{selfid} #{hops}"
    # if hops < 2 do
    if selfid == String.slice(receiverId, 1..10) do
      # IO.puts("here")
      GenServer.cast(String.to_atom(senderId), {:message_received, hops, receiverId, list_traverse})
    else
      {level, slot} = anotherMatch(String.slice(receiverId, 1..10), selfid, routetable)
      my_closest_connection = cond do
                                routetable[level][slot] != nil ->
                                  routetable[level][slot]
                                backupRoutetable1[level][slot] != nil ->
                                  backupRoutetable1[level][slot]
                                true -> backupRoutetable2[level][slot]
                              end
      new_list_traverse = list_traverse ++ [my_closest_connection]
      if my_closest_connection == selfid do
        IO.puts("Sending self")
      end
      # IO.puts("#{routetable[level][slot]}")
      GenServer.cast(
        String.to_atom("n" <> my_closest_connection),
        {:routing, numNodes, numRequests, hops + 1, senderId, receiverId, new_list_traverse}
      )
      # GenServer.cast(String.to_atom("n"<>my_closest_connection), {:routing, numNodes, numRequests, hops+1, senderId, receiverId})
    end
    # end
    {:noreply, {selfid, routetable,backupRoutetable1,backupRoutetable2, numRequests, zzzz, backpointerList}}
  end
end
