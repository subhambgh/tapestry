defmodule TapestryNode do
    use GenServer

    def start_link(x,num_created,numRequests) do
        input_srt = Integer.to_string(x)
        [{_,nodeid}] =  :ets.lookup(:hashList,Integer.to_string(x))
        GenServer.start_link(__MODULE__, {nodeid,num_created, numRequests}, name: String.to_atom("n#{nodeid}"))
    end

    def init({selfid,num_created, numRequests}) do
        routetable = Matrix.from_list(Enum.map(1..8, fn n -> Enum.map(1..16, fn n-> [] end) end))
        hashList = Enum.map 1..num_created, fn(x) -> elem(Enum.at(:ets.lookup(:hashList,Integer.to_string(x)),0),1) end
        hashList = hashList -- [selfid]
        routetable = routeTableBuilder( routetable, hashList,selfid )
        routetable = add_self(selfid, routetable, 1 )
        #Matrix.to_list(routetable)
        IO.puts("#{selfid} #{inspect routetable}")
        {:ok, {selfid,routetable,numRequests,0}}
    end


	def add_self(selfid, routetable, current_level) do

        if current_level == 9 do
            routetable
        else
            #IO.puts "adding #{current_level}"
            {column, _} = Integer.parse(String.at(selfid,current_level-1), 16)
            routetablenew = put_in(routetable[current_level-1][column], selfid)
            add_self(selfid, routetablenew, current_level+1)
        end


    end


    def match(nodeid,selfid) do
      index = Enum.find_index(0..7, fn i -> String.at(nodeid,i) != String.at(selfid,i) end)
      #IO.puts "index = #{index} #{nodeid} #{selfid}"
      case index do
        0 ->
          {0,elem(Integer.parse(String.at(nodeid,0),16),0)}
        _->
          {index,elem(Integer.parse(String.at(nodeid,index),16),0)}
      end
    end

    #returns closest neighbour of selfid b/w [prevNeigh and newNeigh]
    #comparing hashvalues
    def closer(selfid,prevNeigh,newNeigh) do
      {pLevel,pSlot} = match(prevNeigh,selfid)
      {nLevel,nSlot} = match(newNeigh,selfid)
      cond do
        pLevel==nLevel ->
            if Kernel.abs(elem(Integer.parse(String.at(selfid,pLevel),16),0)-elem(Integer.parse(String.at(prevNeigh,pLevel),16),0))-
            Kernel.abs(elem(Integer.parse(String.at(selfid,nLevel),16),0)-elem(Integer.parse(String.at(newNeigh,nLevel),16),0)) > 0 do
              newNeigh
            else
              prevNeigh
            end
        pLevel>nLevel ->
          prevNeigh
        true ->
          newNeigh
      end
    end

    def routeTableBuilder(routetable, [],selfid) do
      routetable
    end

    def routeTableBuilder(routetable, [head | tail],selfid) do
      {level,slot} = match(head,selfid)
      #IO.puts "check #{inspect routetable[level][slot]}"
      newroute = if routetable[level][slot] != nil do
         put_in routetable[level][slot], closer(selfid,routetable[level][slot],head)
      else
         put_in routetable[level][slot], head
      end
      routeTableBuilder(newroute, tail,selfid)
    end

    def handle_cast({:intialize_routing_table,num_created},{selfid,routetable,numRequests,0})do
        # hashList = Enum.map 1..num_created, fn(x) -> elem(Enum.at(:ets.lookup(:hashList,Integer.to_string(x)),0),1) end
        # hashList = hashList -- [selfid]
        # routetable = routeTableBuilder( routetable, hashList,selfid )
        # routetable = add_self(selfid, routetable, 1 )
        # #Matrix.to_list(routetable)
        # IO.puts("#{selfid} #{inspect routetable}")
        {:noreply, {selfid,routetable,numRequests,0}}
    end

    def selectNodeToSend( selfid, listOfNodes, toRemove) do

      x = Enum.random(listOfNodes)
      someNode = "n"<> elem(Enum.at(:ets.lookup(:hashList,Integer.to_string(x)),0),1)
      #IO.inspect someNode
      if someNode == selfid do
        IO.puts("here")
        selectNodeToSend(selfid, listOfNodes, [x])
      else
        someNode
      end

    end

    def route_throught_the_table(routetable, selfid, to_send) do
      {level,slot} = match(selfid, to_send)

      cond do
        routetable[level][slot] == to_send ->
                      routetable[level][slot]
        true ->


       end
    end

    def handle_cast({:goGoGo, numNodes, numRequests}, {selfid,routetable,numRequests2,zzzz}) do

        #IO.inspect(selfid)
        if numRequests != 0 do
          listOfNodes = Enum.map(1..numNodes, fn n -> n end)
          #IO.inspect(listOfNodes)

          to_send = selectNodeToSend("n"<> selfid, listOfNodes, [])
          IO.puts("#{selfid} - #{to_send}")

          {level,slot} = match(selfid, String.slice(to_send, 1..100))
          my_closest_connection = routetable[level][slot]
          GenServer.cast(String.to_atom("n"<>my_closest_connection), {:routing, numNodes, numRequests, 1, "n"<> selfid, to_send})

          GenServer.cast(self, {:goGoGo, numNodes, numRequests-1})
        end

        {:noreply, {selfid,routetable,numRequests2,zzzz}}
    end


    def handle_cast({:routing, numNodes, numRequests, hops, senderId, receiverId}, {selfid,routetable,numRequests,zzzz}) do


        {:noreply, {selfid,routetable,numRequests,zzzz}}
    end

    def handle_cast({:message_received, numNodes, numRequests, hops, senderId, receiverId}, {selfid,routetable,numRequests,zzzz}) do


        {:noreply, {selfid,routetable,numRequests,zzzz}}
    end


end
