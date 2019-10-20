defmodule TapestryNode do
    use GenServer

    def start_link(x,_,numRequests) do
        input_srt = Integer.to_string(x)
        nodeid = Base.encode16(:crypto.hash(:sha, input_srt))
        GenServer.start_link(__MODULE__, {nodeid,numRequests}, name: String.to_atom("n#{nodeid}"))
    end

    def init({selfid,numRequests}) do
        routetableblueprint = Matrix.from_list(Enum.map(1..8, fn n -> Enum.map(1..16, fn n-> [] end) end))
        routetable =  add_self(selfid, routetableblueprint, 1)
        {:ok, {selfid,routetable,numRequests,1}}
    end

    def add_self(selfid, routetable, current_level) do
        
        if current_level == 9 do
            routetable
        else
            IO.puts "adding #{current_level}"
            {column, _} = Integer.parse(String.at(selfid,current_level-1), 16) 
            routetablenew = put_in(routetable[current_level-1][column], selfid)
            add_self(selfid, routetablenew, current_level+1)
        end


    end


    def handle_cast({:intialize_routing_table},{selfid,routetable,req,num_created})do
      
    end
end
