%%% Test REPL command matching
%%% This tests that REPL commands use EXACT matching, not prefix matching

-module(test_repl_command_matching).
-include_lib("eunit/include/eunit.hrl").

%% Test helper function to simulate command matching logic
matches_command(CommandPattern, Input) ->
    case Input of
        CommandPattern ++ Rest when Rest =:= [] -> true;
        CommandPattern ++ Rest when Rest =:= " " -> true;  % test_tool style
        _ -> false
    end.

%% Better pattern (used by most commands)
matches_command_better(CommandPattern, Input) ->
    case Input of
        CommandPattern ++ Rest when Rest =:= [] -> true;
        CommandPattern ++ Rest when hd(Rest) =:= $\s -> true;
        CommandPattern ++ Rest when hd(Rest) =:= $\t -> true;
        _ -> false
    end.

command_matching_test_() ->
    [
        %% Test 1: Exact command should match
        ?_assertEqual(true, matches_command("test_tool", "test_tool")),
        
        %% Test 2: Command with trailing space should match
        ?_assertEqual(true, matches_command("test_tool", "test_tool ")),
        
        %% Test 3: Command with extra characters should NOT match
        ?_assertEqual(false, matches_command("test_tool", "test_tools")),
        
        %% Test 4: Command prefix should NOT match
        ?_assertEqual(false, matches_command("test", "test_tool")),
        
        %% Test 5: Command suffix should NOT match
        ?_assertEqual(false, matches_command("tool", "test_tool")),
        
        %% Test 6: Empty string should NOT match
        ?_assertEqual(false, matches_command("test_tool", "")),
        
        %% Test 7: Case sensitivity
        ?_assertEqual(false, matches_command("test_tool", "TEST_TOOL")),
        ?_assertEqual(false, matches_command("test_tool", "Test_Tool")),
        
        %% Test 8: With tab character (should not match with current pattern)
        ?_assertEqual(false, matches_command("test_tool", "test_tool\t")),
        
        %% Test 9: Better pattern handles tabs
        ?_assertEqual(true, matches_command_better("test_tool", "test_tool\t")),
        
        %% Test 10: Better pattern still rejects prefix
        ?_assertEqual(false, matches_command_better("test_tool", "test_tools"))
    ].