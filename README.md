Unofficial Evernote SDK for Lua
========================================================
Evernote API version 1.25

Overview
--------
This SDK contains Evernote cloud API in Lua language generated from the Thrift
interface released by Evernote as well as the `thrift` runtime library 
mainly for Lua 5.1 and LuaJIT. 

Prerequisites
-------------
`LuaSocket` and `LuaSec` are required for secure HTTP requests to Evernote. For 
Ubuntu users you need to install `Luarocks` first and then install the above 
two rocks by `luarocks` through the following commands:
```
sudo apt-get install luarocks
sudo luarocks install luasocket luasec
```
Building & Testing
------------------
You also need to build some binary objects for the `thrift` runtime library.
A `Makefile` is provided in the `thrift` directory to simplify this task.
```
cd thrift && make
```
You can test the thrift runtime for both client side and server side with these
commands:
```
cd ../test && lua5.1 ./test_basic_server.lua &
lua5.1 ./test_basic_client.lua
```

if everything goes right the server and client will both return quietly.

To test evernote client you need the `busted` test framework which is also provided
as a rock in `luarocks` which can be installed by:
```
sudo luarocks install busted
```

You need to obtain a developer token [here](https://sandbox.evernote.com/api/DeveloperToken.action)
to test evernote client. After replacing the faked `authToken` in `test_evernote_client.lua`
with your own developer token just run this command:
```
cd test && busted test_evernote_client.lua
```

