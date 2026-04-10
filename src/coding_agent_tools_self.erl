-module(coding_agent_tools_self).
-export([execute/2]).

execute(<<"reload_module">>, #{<<"module">> := Module}) ->
    case safe_binary_to_existing_atom(Module) of
        {ok, ModuleAtom} ->
            case coding_agent_self:reload_module(ModuleAtom) of
                #{success := true} = Result -> Result;
                #{success := false, error := Error} -> #{<<"success">> => false, <<"error">> => Error}
            end;
        {error, Reason} ->
            #{<<"success">> => false, <<"error">> => Reason}
    end;

execute(<<"get_self_modules">>, _Args) ->
    {ok, Modules} = coding_agent_self:get_modules(),
    #{<<"success">> => true, <<"modules">> => Modules};

execute(<<"analyze_self">>, _Args) ->
    {ok, Analysis} = coding_agent_self:analyze_self(),
    #{<<"success">> => true, <<"analysis">> => Analysis};

execute(<<"deploy_module">>, #{<<"module">> := Module, <<"code">> := Code}) ->
    case safe_binary_to_existing_atom(Module) of
        {ok, ModuleAtom} ->
            case coding_agent_self:deploy_improvement(ModuleAtom, Code) of
                #{success := true} = Result -> Result;
                #{success := false, error := Error} -> #{<<"success">> => false, <<"error">> => Error}
            end;
        {error, Reason} ->
            #{<<"success">> => false, <<"error">> => Reason}
    end;

execute(<<"create_checkpoint">>, _Args) ->
    case coding_agent_self:create_checkpoint() of
        #{success := true} = Result -> Result;
        #{success := false, error := Error} -> #{<<"success">> => false, <<"error">> => Error}
    end;

execute(<<"restore_checkpoint">>, #{<<"checkpoint_id">> := CheckpointId}) ->
    case coding_agent_self:restore_checkpoint(CheckpointId) of
        #{success := true} = Result -> Result;
        #{success := false, error := Error} -> #{<<"success">> => false, <<"error">> => Error}
    end;

execute(<<"list_checkpoints">>, _Args) ->
    {ok, Checkpoints} = coding_agent_self:list_checkpoints(),
    #{<<"success">> => true, <<"checkpoints">> => Checkpoints}.

%% Helper function to safely convert binary to existing atom
safe_binary_to_existing_atom(Binary) when is_binary(Binary) ->
    try binary_to_existing_atom(Binary, utf8) of
        Atom -> {ok, Atom}
    catch
        error:badarg ->
            {error, <<"Module does not exist or is not loaded">>}
    end;
safe_binary_to_existing_atom(Other) ->
    {error, iolist_to_binary([<<"Expected binary, got: ">>, io_lib:format("~p", [Other])])}.