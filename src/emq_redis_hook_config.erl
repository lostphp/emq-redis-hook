%%--------------------------------------------------------------------
%% Copyright (c) 2013-2018 EMQ Enterprise, Inc. (http://emqtt.io)
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module (emq_redis_hook_config).

-define(APP, emq_redis_hook).

-define(LOG(Level, Format, Args), lager:Level("Redis Hook: " ++ Format, Args)).

-export ([register/0, unregister/0]).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
register() ->
    clique_config:load_schema([code:priv_dir(?APP)], ?APP),
    register_formatter(),
    register_config().

unregister() ->
    unregister_formatter(),
    unregister_config(),
    clique_config:unload_schema(?APP).

%%--------------------------------------------------------------------
%% Get ENV Register formatter
%%--------------------------------------------------------------------
register_formatter() ->
    [clique:register_formatter(cuttlefish_variable:tokenize(Key),
        fun formatter_callback/2) || Key <- keys()].

formatter_callback([_, _, "server"], Params) ->
    ?LOG(info,"server :::: ~p ",[Params]),
    lists:concat([proplists:get_value(host, Params), ":", proplists:get_value(port, Params)]);
formatter_callback([_, _, "pool"], Params) ->
    ?LOG(info,"pool :::: ~p ",[Params]),
    proplists:get_value(pool_size, Params);
formatter_callback([_, _, Key], Params) ->
    ?LOG(info,"Key :::: ~p ",[Params]),
    proplists:get_value(list_to_atom(Key), Params).

%%--------------------------------------------------------------------
%% UnRegister formatter
%%--------------------------------------------------------------------
unregister_formatter() ->
    [clique:unregister_formatter(cuttlefish_variable:tokenize(Key)) || Key <- keys()].

%%--------------------------------------------------------------------
%% Set ENV Register Config
%%--------------------------------------------------------------------
register_config() ->
    Keys = keys(),
    [clique:register_config(Key , fun config_callback/2) || Key <- Keys],
    clique:register_config_whitelist(Keys, ?APP).

config_callback([_, _, "server"], Value0) ->
    ?LOG(info,"server :::: ~p ",[Value0]),
    {Host, Port} = parse_servers(Value0),
    {ok, Env} = application:get_env(?APP, server),
    Env1 = lists:keyreplace(host, 1, Env, {host, Host}),
    Env2 = lists:keyreplace(port, 1, Env1, {port, Port}),
    application:set_env(?APP, server, Env2),
    " successfully\n";
config_callback([_, _, "pool"], Value) ->
    ?LOG(info,"pool :::: ~p ",[Value]),
    {ok, Env} = application:get_env(?APP, server),
    application:set_env(?APP, server, lists:keyreplace(pool_size, 1, Env, {pool_size, Value})),
    " successfully\n";
config_callback([_, _, _, "key"], Value) ->
    ?LOG(info,"key :::: ~p ",[Value]),
    application:set_env(?APP, key, Value),
    " successfully\n";
config_callback([_, _, Key0], Value) ->
    ?LOG(info,"key ~p :::: value ~p ",[Key0,Value]),
    Key = list_to_atom(Key0),
    {ok, Env} = application:get_env(?APP, server),
    application:set_env(?APP, server, lists:keyreplace(Key, 1, Env, {Key, Value})),
    " successfully\n".

%%--------------------------------------------------------------------
%% UnRegister config
%%--------------------------------------------------------------------
unregister_config() ->
    Keys = keys(),
    [clique:unregister_config(Key) || Key <- Keys],
    clique:unregister_config_whitelist(Keys, ?APP).

%%--------------------------------------------------------------------
%% Internal Functions
%%--------------------------------------------------------------------
keys() ->
    ["redis.hook.server",
     "redis.hook.pool",
     "redis.hook.password",
     "redis.hook.database",
     "redis.hook.message.key"].

parse_servers(Value) ->
    case string:tokens(Value, ":") of
        [Domain]       -> {Domain, 3306};
        [Domain, Port] -> {Domain, list_to_integer(Port)}
    end.