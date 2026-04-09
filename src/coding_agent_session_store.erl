-module(coding_agent_session_store).
-behaviour(gen_server).

-export([start_link/0, save_session/2, load_session/1, delete_session/1, list_sessions/0,
         list_sessions_with_metadata/0, get_session_metadata/1, save_session_metadata/2,
         cleanup_old_sessions/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(MAX_SESSION_AGE_DAYS, 30).
-define(MAX_SESSIONS, 100).

-record(state, {dir :: string()}).
-define(SESSIONS_DIR, ".tarha/sessions").

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Dir = get_sessions_dir(),
    filelib:ensure_dir(Dir ++ "/"),
    {ok, #state{dir = Dir}}.

get_sessions_dir() ->
    case application:get_env(coding_agent, sessions_dir) of
        {ok, Dir} -> Dir;
        _ ->
            case file:get_cwd() of
                {ok, Cwd} -> filename:join(Cwd, ?SESSIONS_DIR);
                _ -> ?SESSIONS_DIR
            end
    end.

handle_call({save, SessionId, Data}, _From, State = #state{dir = Dir}) ->
    Filename = session_file(Dir, SessionId),
    JsonData = jsx:encode(Data),
    case file:write_file(Filename, JsonData) of
        ok -> {reply, ok, State};
        {error, Reason} -> {reply, {error, Reason}, State}
    end;

handle_call({load, SessionId}, _From, State = #state{dir = Dir}) ->
    Filename = session_file(Dir, SessionId),
    case file:read_file(Filename) of
        {ok, Content} ->
            case jsx:is_json(Content) of
                true ->
                    %% Use {labels, atom} to convert JSON keys to atoms
                    %% This matches how we access the data in restore_state
                    Data = jsx:decode(Content, [return_maps, {labels, atom}]),
                    {reply, {ok, Data}, State};
                false ->
                    {reply, {error, invalid_json}, State}
            end;
        {error, enoent} ->
            {reply, {error, not_found}, State};
        {error, Reason} ->
            {reply, {error, Reason}, State}
    end;

handle_call({delete, SessionId}, _From, State = #state{dir = Dir}) ->
    Filename = session_file(Dir, SessionId),
    case file:delete(Filename) of
        ok -> {reply, ok, State};
        {error, enoent} -> {reply, ok, State};
        {error, Reason} -> {reply, {error, Reason}, State}
    end;

handle_call(list, _From, State = #state{dir = Dir}) ->
    case file:list_dir(Dir) of
        {ok, Files} ->
            SessionIds = [iolist_to_binary(filename:rootname(F)) || F <- Files, filename:extension(F) =:= ".json"],
            {reply, {ok, SessionIds}, State};
        {error, enoent} ->
            {reply, {ok, []}, State};
        {error, Reason} ->
            {reply, {error, Reason}, State}
    end;

handle_call(_Req, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

session_file(Dir, SessionId) when is_binary(SessionId) ->
    filename:join(Dir, <<SessionId/binary, ".json">>);
session_file(Dir, SessionId) when is_list(SessionId) ->
    filename:join(Dir, SessionId ++ ".json").

%% Public API

save_session(SessionId, Data) when is_binary(SessionId); is_list(SessionId) ->
    gen_server:call(?MODULE, {save, SessionId, Data}).

load_session(SessionId) when is_binary(SessionId); is_list(SessionId) ->
    gen_server:call(?MODULE, {load, SessionId}).

delete_session(SessionId) when is_binary(SessionId); is_list(SessionId) ->
    gen_server:call(?MODULE, {delete, SessionId}).

list_sessions() ->
    gen_server:call(?MODULE, list).

list_sessions_with_metadata() ->
    {ok, SessionIds} = list_sessions(),
    lists:filtermap(fun(Id) ->
        case get_session_metadata(Id) of
            {ok, Meta} -> {true, Meta#{id => Id}};
            _ -> {true, #{id => Id}}
        end
    end, SessionIds).

get_session_metadata(SessionId) ->
    case load_session(SessionId) of
        {ok, Data} ->
            Summary = generate_summary(Data),
            Meta = #{
                model => maps:get(model, Data, <<"unknown">>),
                message_count => length(maps:get(messages, Data, [])),
                estimated_tokens => maps:get(estimated_tokens, Data, 0),
                tool_calls => maps:get(tool_calls, Data, 0),
                summary => Summary,
                updated_at => filelib:last_modified(session_file(get_sessions_dir_cached(), SessionId))
            },
            {ok, Meta};
        {error, Reason} ->
            {error, Reason}
    end.

save_session_metadata(_SessionId, _Meta) ->
    ok.

cleanup_old_sessions() ->
    {ok, Sessions} = list_sessions_with_metadata(),
    Now = calendar:local_time(),
    NowSec = calendar:datetime_to_gregorian_seconds(Now),
    Cutoff = NowSec - (?MAX_SESSION_AGE_DAYS * 86400),
    Sorted = lists:sort(fun(A, B) ->
        compare_session_time(A, B)
    end, Sessions),
    ToDelete = lists:filter(fun(S) ->
        case maps:get(updated_at, S, undefined) of
            undefined -> false;
            DateTime ->
                Sec = calendar:datetime_to_gregorian_seconds(DateTime),
                Sec < Cutoff
        end
    end, Sorted),
    lists:foreach(fun(S) ->
        delete_session(maps:get(id, S))
    end, ToDelete),
    case length(Sorted) > ?MAX_SESSIONS of
        true ->
            Excess = lists:sublist(Sorted, ?MAX_SESSIONS + 1, length(Sorted) - ?MAX_SESSIONS),
            lists:foreach(fun(S) -> delete_session(maps:get(id, S)) end, Excess);
        false -> ok
    end,
    ok.

generate_summary(Data) ->
    Messages = maps:get(messages, Data, []),
    case find_first_user_message(Messages) of
        undefined -> <<"Empty session">>;
        Msg ->
            Content = maps:get(<<"content">>, Msg, <<"">>),
            case byte_size(Content) of
                N when N > 80 -> <<(binary:part(Content, 0, 80))/binary, "...">>;
                _ -> Content
            end
    end.

find_first_user_message([]) -> undefined;
find_first_user_message([#{<<"role">> := <<"user">>, <<"content">> := Content} = Msg | _])
    when Content =/= <<>>, Content =/= nil -> Msg;
find_first_user_message([_ | Rest]) -> find_first_user_message(Rest).

get_sessions_dir_cached() ->
    case application:get_env(coding_agent, sessions_dir) of
        {ok, Dir} -> Dir;
        _ ->
            case file:get_cwd() of
                {ok, Cwd} -> filename:join(Cwd, ?SESSIONS_DIR);
                _ -> ?SESSIONS_DIR
            end
    end.

compare_session_time(A, B) ->
    TA = case maps:get(updated_at, A, undefined) of undefined -> 0; DTA -> calendar:datetime_to_gregorian_seconds(DTA) end,
    TB = case maps:get(updated_at, B, undefined) of undefined -> 0; DTB -> calendar:datetime_to_gregorian_seconds(DTB) end,
    TA >= TB.
