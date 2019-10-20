defmodule TapestryNode do
    use GenServer

    def start_link(x,_,numRequests) do
        input_srt = Integer.to_string(x)
        [{_,nodeid}] =  :ets.lookup(:hashList,Integer.to_string(x))
        GenServer.start_link(__MODULE__, {nodeid,numRequests}, name: String.to_atom("n#{nodeid}"))
    end

    def init({selfid,numRequests}) do
        routetable = Matrix.from_list([
          [],[],[],[],[],[],[],[]
          ])
        {:ok, {selfid,routetable,numRequests,0}}
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

    def closer(selfid,prevNeigh,newNeigh) do
      if elem(Integer.parse(String.at(selfid,0),16),0)-elem(Integer.parse(String.at(prevNeigh,0),16),0)-
      elem(Integer.parse(String.at(selfid,0),16),0)-elem(Integer.parse(String.at(newNeigh,0),16),0) > 0 do
        newNeigh
      else
        prevNeigh
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
        hashList = Enum.map 1..num_created, fn(x) -> elem(Enum.at(:ets.lookup(:hashList,Integer.to_string(x)),0),1) end
        hashList = hashList -- [selfid]
        routetable = routeTableBuilder( routetable, hashList,selfid )
        #Matrix.to_list(routetable)
        IO.puts("#{selfid} #{inspect routetable}")
        {:noreply, {selfid,routetable,numRequests,0}}
    end
end
