-module(coding_agent_tools_git).
-export([execute/2]).

execute(<<"git_status">>, _Args) ->
    coding_agent_tools:report_progress(<<"git_status">>, <<"starting">>, #{}),
    Result = run_git_command("git status --short"),
    coding_agent_tools:report_progress(<<"git_status">>, <<"complete">>, #{}),
    Result;

execute(<<"git_diff">>, Args) ->
    File = maps:get(<<"file">>, Args, undefined),
    Staged = maps:get(<<"staged">>, Args, false),
    Cmd = case {Staged, File} of
        {true, undefined} -> "git diff --cached";
        {true, F} -> "git diff --cached " ++ binary_to_list(F);
        {false, undefined} -> "git diff";
        {false, F} -> "git diff " ++ binary_to_list(F)
    end,
    coding_agent_tools:report_progress(<<"git_diff">>, <<"starting">>, #{command => list_to_binary(Cmd)}),
    Result = run_git_command(Cmd),
    coding_agent_tools:report_progress(<<"git_diff">>, <<"complete">>, #{}),
    Result;

execute(<<"git_log">>, Args) ->
    Count = maps:get(<<"count">>, Args, 10),
    Format = maps:get(<<"format">>, Args, <<"oneline">>),
    Cmd = "git log --max-count=" ++ integer_to_list(Count) ++ " --format=" ++ binary_to_list(Format),
    coding_agent_tools:report_progress(<<"git_log">>, <<"starting">>, #{count => Count}),
    Result = run_git_command(Cmd),
    coding_agent_tools:report_progress(<<"git_log">>, <<"complete">>, #{}),
    Result;

execute(<<"git_add">>, #{<<"files">> := Files}) ->
    FileList = string:join([binary_to_list(F) || F <- Files], " "),
    Cmd = "git add " ++ FileList,
    coding_agent_tools:report_progress(<<"git_add">>, <<"starting">>, #{files => Files}),
    Result = run_git_command(Cmd),
    coding_agent_tools:report_progress(<<"git_add">>, <<"complete">>, #{}),
    Result;

execute(<<"git_commit">>, #{<<"message">> := Msg} = Args) ->
    case coding_agent_tools:safety_check(<<"git_commit">>, Args) of
        skip -> #{<<"success">> => false, <<"error">> => <<"Operation skipped by safety check">>};
        {modify, NewArgs} -> execute(<<"git_commit">>, NewArgs);
        proceed ->
            Cmd = "git commit -m '" ++ binary_to_list(Msg) ++ "'",
            coding_agent_tools:report_progress(<<"git_commit">>, <<"starting">>, #{}),
            Result = run_git_command(Cmd),
            coding_agent_tools:log_operation(<<"git_commit">>, Msg, Result),
            coding_agent_tools:report_progress(<<"git_commit">>, <<"complete">>, #{}),
            Result
    end;

execute(<<"git_branch">>, #{<<"action">> := Action} = Args) ->
    Name = maps:get(<<"name">>, Args, undefined),
    Cmd = case {Action, Name} of
        {<<"create">>, N} -> "git checkout -b " ++ binary_to_list(N);
        {<<"switch">>, N} -> "git checkout " ++ binary_to_list(N);
        {<<"list">>, _} -> "git branch";
        {<<"delete">>, N} -> "git branch -d " ++ binary_to_list(N);
        _ -> "git branch"
    end,
    coding_agent_tools:report_progress(<<"git_branch">>, <<"starting">>, #{action => Action}),
    Result = run_git_command(Cmd),
    coding_agent_tools:report_progress(<<"git_branch">>, <<"complete">>, #{}),
    Result;

execute(<<"git_stash">>, Args) ->
    Action = maps:get(<<"action">>, Args, <<"list">>),
    Message = maps:get(<<"message">>, Args, undefined),
    Cmd = case Action of
        <<"push">> ->
            case Message of
                undefined -> "git stash";
                Msg -> "git stash push -m \"" ++ binary_to_list(Msg) ++ "\""
            end;
        <<"pop">> -> "git stash pop";
        <<"list">> -> "git stash list";
        <<"drop">> -> "git stash drop"
    end,
    coding_agent_tools:report_progress(<<"git_stash">>, <<"starting">>, #{action => Action}),
    Result = run_git_command(Cmd),
    coding_agent_tools:report_progress(<<"git_stash">>, <<"complete">>, #{}),
    Result#{<<"action">> => Action};

execute(<<"git_pull">>, Args) ->
    Remote = maps:get(<<"remote">>, Args, <<"origin">>),
    Branch = maps:get(<<"branch">>, Args, undefined),
    Rebase = maps:get(<<"rebase">>, Args, false),
    Cmd = case {Rebase, Branch} of
        {true, undefined} -> "git pull --rebase";
        {true, B} -> "git pull --rebase " ++ binary_to_list(Remote) ++ " " ++ binary_to_list(B);
        {false, undefined} -> "git pull";
        {false, B} -> "git pull " ++ binary_to_list(Remote) ++ " " ++ binary_to_list(B)
    end,
    coding_agent_tools:report_progress(<<"git_pull">>, <<"starting">>, #{remote => Remote}),
    Result = run_git_command(Cmd),
    coding_agent_tools:report_progress(<<"git_pull">>, <<"complete">>, #{}),
    Result;

execute(<<"git_push">>, Args) ->
    Force = maps:get(<<"force">>, Args, false),
    case Force of
        true ->
            case coding_agent_tools:safety_check(<<"git_push">>, Args) of
                skip -> #{<<"success">> => false, <<"error">> => <<"Force push blocked by safety check">>};
                {modify, NewArgs} -> execute(<<"git_push">>, NewArgs);
                proceed -> do_git_push(Args, true)
            end;
        false ->
            do_git_push(Args, false)
    end;

execute(<<"git_tag">>, Args) ->
    Action = maps:get(<<"action">>, Args, <<"list">>),
    Name = maps:get(<<"name">>, Args, undefined),
    Message = maps:get(<<"message">>, Args, undefined),
    Cmd = case {Action, Name, Message} of
        {<<"create">>, N, undefined} -> "git tag " ++ binary_to_list(N);
        {<<"create">>, N, Msg} -> "git tag -a " ++ binary_to_list(N) ++ " -m \"" ++ binary_to_list(Msg) ++ "\"";
        {<<"list">>, _, _} -> "git tag -n";
        {<<"delete">>, N, _} -> "git tag -d " ++ binary_to_list(N)
    end,
    coding_agent_tools:report_progress(<<"git_tag">>, <<"starting">>, #{action => Action}),
    Result = run_git_command(Cmd),
    coding_agent_tools:report_progress(<<"git_tag">>, <<"complete">>, #{}),
    Result;

execute(<<"git_merge">>, Args) ->
    Branch = maps:get(<<"branch">>, Args, undefined),
    Squash = maps:get(<<"squash">>, Args, false),
    Message = maps:get(<<"message">>, Args, undefined),
    Cmd = case {Squash, Branch} of
        {true, B} ->
            MergeCmd = "git merge --squash " ++ binary_to_list(B),
            case Message of
                undefined -> MergeCmd;
                Msg -> MergeCmd ++ " && git commit -m \"" ++ binary_to_list(Msg) ++ "\""
            end;
        {false, B} -> "git merge " ++ binary_to_list(B)
    end,
    coding_agent_tools:report_progress(<<"git_merge">>, <<"starting">>, #{branch => Branch}),
    Result = run_git_command(Cmd),
    coding_agent_tools:report_progress(<<"git_merge">>, <<"complete">>, #{}),
    Result;

execute(<<"git_remote">>, Args) ->
    Action = maps:get(<<"action">>, Args, <<"list">>),
    Name = maps:get(<<"name">>, Args, undefined),
    Url = maps:get(<<"url">>, Args, undefined),
    Cmd = case {Action, Name, Url} of
        {<<"list">>, _, _} -> "git remote -v";
        {<<"add">>, N, U} -> "git remote add " ++ binary_to_list(N) ++ " " ++ binary_to_list(U);
        {<<"remove">>, N, _} -> "git remote remove " ++ binary_to_list(N)
    end,
    coding_agent_tools:report_progress(<<"git_remote">>, <<"starting">>, #{action => Action}),
    Result = run_git_command(Cmd),
    coding_agent_tools:report_progress(<<"git_remote">>, <<"complete">>, #{}),
    Result.

%% Internal helpers

do_git_push(Args, Force) ->
    Remote = maps:get(<<"remote">>, Args, <<"origin">>),
    Branch = maps:get(<<"branch">>, Args, undefined),
    ForceFlag = case Force of true -> " --force"; false -> "" end,
    Cmd = case Branch of
        undefined -> "git push" ++ ForceFlag;
        B -> "git push " ++ binary_to_list(Remote) ++ " " ++ binary_to_list(B) ++ ForceFlag
    end,
    coding_agent_tools:report_progress(<<"git_push">>, <<"starting">>, #{remote => Remote, force => Force}),
    Result = run_git_command(Cmd),
    coding_agent_tools:report_progress(<<"git_push">>, <<"complete">>, #{}),
    Result.

run_git_command(Cmd) ->
    case os:cmd(Cmd ++ " 2>&1") of
        [] -> #{<<"success">> => true, <<"output">> => <<"">>};
        Result ->
            CleanResult = coding_agent_tools:clean_output(Result),
            #{<<"success">> => true, <<"output">> => CleanResult}
    end.