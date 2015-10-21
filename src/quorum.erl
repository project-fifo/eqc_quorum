%%%-------------------------------------------------------------------
%%% @author Thomas Arts <thomas@ThomasComputer.local>
%%% @copyright (C) 2015, Thomas Arts
%%% @doc
%%%
%%% @end
%%% Created : 21 Oct 2015 by Thomas Arts <thomas@ThomasComputer.local>
%%%-------------------------------------------------------------------
-module(quorum).

-export([start/0, init/0]).


start() ->
  {ok, spawn(quorum, init, [])}.

init() ->
  loop([]).

loop(QuorumPids) ->
  receive
    {quorum_pids, From, Pids} ->
      From ! ack,
      loop(Pids);
    {ask_int, From} ->
      From ! yes,
      loop(QuorumPids);
    {ask, From} ->
      [ P ! {ask_int, self()} || P<-QuorumPids],
      Answers = [ receive
                    yes -> yes
                  after 100 -> no
                  end || _P <- QuorumPids],
      Agree = [ myself | [ yes || yes <- Answers]],
      case length(Agree) > ((length(QuorumPids)+1) / 2) of
        true  -> From ! yes;
        false -> From ! no
      end,
      loop(QuorumPids)
  end.
