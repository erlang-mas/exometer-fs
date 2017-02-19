%%%-----------------------------------------------------------------------------
%%% @doc Exometer filesystem reporter.
%%% @end
%%%-----------------------------------------------------------------------------

-module(exometer_report_fs).

-behaviour(exometer_report).

%%% Exometer report callbacks
-export(
   [
    exometer_init/1,
    exometer_subscribe/5,
    exometer_unsubscribe/4,
    exometer_report/5,
    exometer_call/3,
    exometer_cast/2,
    exometer_info/2,
    exometer_newentry/2,
    exometer_setopts/4,
    exometer_terminate/2
   ]).

-record(state, {base_dir :: string(),
                files    :: dict:dict()}).

%%%=============================================================================
%%% Exometer report callbacks
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
exometer_init(Opts) ->
    BaseDir = get_opt(base_dir, Opts),
    ok = filelib:ensure_dir(BaseDir),
    {ok, #state{base_dir = BaseDir,
                files    = dict:new()}}.

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
exometer_subscribe(Metric, _DataPoint, _Interval, _Extra,
                   State = #state{base_dir = BaseDir, files = Files}) ->
    Path = build_path(BaseDir, Metric),
    File = open_file(Path),
    {ok, State#state{files = dict:store(Metric, File, Files)}}.

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
exometer_unsubscribe(Metric, _DataPoint, _Extra,
                     State = #state{files = Files}) ->
    File = dict:fetch(Metric, Files),
    close_file(File),
    {ok, State#state{files = dict:erase(Metric, Files)}}.

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
exometer_report(Metric, _DataPoint, _Extra, Value,
                State = #state{files = Files})  ->
    File = dict:fetch(Metric, Files),
    write_entry(Value, File),
    {ok, State}.

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
exometer_call(_Msg, _From, State) ->
    {ok, State}.

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
exometer_cast(_Msg, State) ->
    {ok, State}.

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
exometer_info(_Msg, State) ->
    {ok, State}.

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
exometer_newentry(_Entry, State) ->
    {ok, State}.

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
exometer_setopts(_Metric, _Options, _Status, State) ->
    {ok, State}.

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
exometer_terminate(_Reason, #state{files = Files}) ->
    [close_file(File) || {_Metric, File} <- dict:to_list(Files)].

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
build_path(BaseDir, Metric) ->
    filename:join(BaseDir, metric_to_path(Metric)).

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
metric_to_path([LastComponent]) ->
    stringify(LastComponent);
metric_to_path([Component | T]) ->
    filename:join(stringify(Component), metric_to_path(T)).

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
open_file(Path) ->
    ok = filelib:ensure_dir(Path),
    {ok, File} = file:open(Path, [append, delayed_write, raw]),
    File.

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
close_file(File) ->
    file:close(File).

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
write_entry(Value, File) ->
    file:write(File, io_lib:fwrite("~s~n", [value(Value)])).

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
stringify(T) when is_atom(T) ->
    atom_to_list(T);
stringify(T) when is_list(T) ->
    T;
stringify(T) when is_integer(T) ->
    integer_to_list(T);
stringify(T) ->
    io_lib:format("~w", [T]).

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
value(V) when is_integer(V) -> integer_to_list(V);
value(V) when is_float(V)   -> io_lib:format("~f", [V]);
value(_) -> "0".

%%------------------------------------------------------------------------------
%% @private
%%------------------------------------------------------------------------------
get_opt(K, Opts) ->
    exometer_util:get_opt(K, Opts).
