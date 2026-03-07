#!/usr/bin/env escript
%% -*- erlang -*-
%%! -pa _build/default/lib/coding_agent/ebin -pa _build/default/lib/hackney/ebin -pa _build/default/lib/jsx/ebin

main(_) ->
    io:format("~n=== REPL Command Matching Tests ===~n~n"),
    
    %% Test the pattern matching logic for commands
    io:format("Test 1: Exact command 'test_tool' should match~n"),
    true = test_command_match("test_tool"),
    io:format("  ✓ 'test_tool' matches~n"),
    
    io:format("~nTest 2: Command with trailing space should match~n"),
    true = test_command_match("test_tool "),
    io:format("  ✓ 'test_tool ' matches~n"),
    
    io:format("~nTest 3: Command with trailing tab should NOT match (current pattern)~n"),
    false = test_command_match("test_tool\t"),
    io:format("  ✓ 'test_tool\\t' does NOT match (expected with current pattern)~n"),
    
    io:format("~nTest 4: Command with extra characters 'test_tools' should NOT match~n"),
    false = test_command_match("test_tools"),
    io:format("  ✓ 'test_tools' does NOT match~n"),
    
    io:format("~nTest 5: Prefix 'test' should NOT match~n"),
    false = test_command_match("test"),
    io:format("  ✓ 'test' does NOT match~n"),
    
    io:format("~nTest 6: Empty string should NOT match~n"),
    false = test_command_match(""),
    io:format("  ✓ '' does NOT match~n"),
    
    io:format("~nTest 7: Case sensitivity~n"),
    false = test_command_match("TEST_TOOL"),
    io:format("  ✓ 'TEST_TOOL' does NOT match~n"),
    false = test_command_match("Test_Tool"),
    io:format("  ✓ 'Test_Tool' does NOT match~n"),
    
    io:format("~nTest 8: Other commands - 'help' matches~n"),
    true = test_command_match_better("help"),
    io:format("  ✓ 'help' matches~n"),
    
    io:format("~nTest 9: 'help ' matches~n"),
    true = test_command_match_better("help "),
    io:format("  ✓ 'help ' matches~n"),
    
    io:format("~nTest 10: 'help\\t' matches (better pattern)~n"),
    true = test_command_match_better("help\t"),
    io:format("  ✓ 'help\\t' matches~n"),
    
    io:format("~nTest 11: 'helper' should NOT match~n"),
    false = test_command_match_better("helper"),
    io:format("  ✓ 'helper' does NOT match~n"),
    
    io:format("~nTest 12: 'helping' should NOT match~n"),
    false = test_command_match_better("helping"),
    io:format("  ✓ 'helping' does NOT match~n"),
    
    io:format("~n=== All Tests Passed! ===~n~n"),
    
    %% Summary
    io:format("Summary:~n"),
    io:format("  - Commands use pattern 'cmd ++ Rest' where Rest =:= [] or Rest starts with space/tab~n"),
    io:format("  - This prevents prefix matching: 'test' does NOT match 'test_tool'~n"),
    io:format("  - This prevents suffix matching: 'test_tools' does NOT match 'test_tool'~n"),
    io:format("  - The pattern requires EXACT command name followed by nothing or whitespace~n"),
    io:format("~n"),
    io:format("ISSUE FOUND:~n"),
    io:format("  The 'test_tool' command uses 'Rest =:= []' and 'Rest =:= \" \"'~n"),
    io:format("  This is MORE restrictive than other commands which use 'hd(Rest) =:= $\\s'~n"),
    io:format("  'test_tool\\t' would be treated as unknown command instead of calling test_tool~n"),
    io:format("~n"),
    ok.

%% This simulates the current test_tool pattern
test_command_match(Input) ->
    case Input of
        "test_tool" ++ Rest when Rest =:= [] -> true;
        "test_tool" ++ Rest when Rest =:= " " -> true;
        _ -> false
    end.

%% This simulates the pattern used by most other commands (help, status, etc.)
test_command_match_better(Input) ->
    case Input of
        "help" ++ Rest when Rest =:= [] -> true;
        "help" ++ Rest when hd(Rest) =:= $\s -> true;
        "help" ++ Rest when hd(Rest) =:= $\t -> true;
        _ -> false
    end.