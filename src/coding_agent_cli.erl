-module(coding_agent_cli).
-export([main/1]).

main([]) ->
    io:format("Usage: coding_agent_cli <command> [args]~n"),
    io:format("Commands:~n"),
    io:format("  ~s~n", [coding_agent_ansi:bright_white("ask <question>") ++ coding_agent_ansi:dim("    - Ask a question in a new session")]);

main(["ask" | QuestionParts]) ->
    Question = string:join(QuestionParts, " "),
    application:ensure_all_started(coding_agent),
    {ok, {_SessionId, _Pid}} = coding_agent_session:new(),
    case coding_agent_session:ask(_SessionId, Question) of
        {ok, Response, _Thinking} ->
            io:format("~s~n", [Response]);
        {error, Reason} ->
            io:format("~s ~p~n", [coding_agent_ansi:bright_red("Error:"), Reason])
    end,
    application:stop(coding_agent);

main([_ | _]) ->
    io:format("~s~n", [coding_agent_ansi:bright_yellow("Unknown command. Use without arguments for help.")]).
