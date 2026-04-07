-module(coding_agent_cli).
-export([main/1]).

main([]) ->
    io:format("Usage: coding_agent_cli <command> [args]~n"),
    io:format("Commands:~n"),
    io:format("  ask <question>    - Ask a question in a new session~n");

main(["ask" | QuestionParts]) ->
    Question = string:join(QuestionParts, " "),
    start_app(),
    {ok, {SessionId, _Pid}} = coding_agent_session:new(),
    case coding_agent_session:ask(SessionId, Question) of
        {ok, Response, _Thinking} ->
            io:format("~s~n", [Response]);
        {error, Reason} ->
            io:format("Error: ~p~n", [Reason])
    end,
    stop_app();

main([_ | _]) ->
    io:format("Unknown command. Use without arguments for help.~n").

start_app() ->
    application:ensure_all_started(coding_agent).

stop_app() ->
    application:stop(coding_agent).