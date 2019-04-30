// MIT License
//
// Copyright 2017-2019 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
// "Promise" symbol is injected dependency from ImpUnit_Promise module,
// while class being tested can be accessed from global scope as "::Promise".

@include "github:electricimp/ConnectionManager/ConnectionManager.lib.nut"
@include __PATH__+"/conf.nut"

const MESSAGE_NAME = "test";
const MESSAGE_DEFAULT = "test_default";
const MESSAGE_WITHOUT_RESPONSE = "test_no_response";
const MESSAGE_WITH_DELAY = "test_with_delay";
const MESSAGE_WITH_LONG_DELAY = "test_with_huge_delay";
const MESSAGE_WITH_SHORT_DELAY = "test_with_small_delay";
const MESSAGE_WITH_NO_HANDLER = "test_with_no_handler";
const MESSAGE_DESTRUCTIVE_RESEND = "test_destructive_resend";
const MESSAGE_DESTRUCTIVE_RESEND_RESPONSE = "test_destructive_resend_response";


const REPLY_NO_MESSAGES = "No messages";
const BASIC_MESSAGE = "basic message";
const DEFAULT_MESSAGE = "default message";

const MESSAGE_WITH_DELAY_SLEEP = 2;
const MESSAGE_WITH_DELAY_LONG_SLEEP = 8;
const MESSAGE_WITH_DELAY_SHORT_SLEEP = 1;

const ERR_REQ_RES_NOT_IDENTICAL = "Request and response messages are not identical";
const ERR_REQ_RES_IDENTICAL = "Request and response messages are identical";

// These variables are used to correctly receive messages in the conditions of execution of the chain of tests.
// Each test will contain these two parameters of MessageManager constructor.
// MessageManager({
//    "firstMessageId":  msgId,
//    "nextIdGenerator": msgIdGenerator
// })
// This approach will be applied for all tests of this library.
local msgId = 0;
local msgIdGenerator = function() {
    return ++msgId;
}.bindenv(this);

function isAgentSide() {
    return imp.environment() == ENVIRONMENT_AGENT;
}

function infoAboutSide() {
    info("Tests will be performed on the " + (isAgentSide() ? "agent" : "device") + "-side");
}

function assertDeepEqualWrap(expected, actual, message = null, compare = true) {
    if (compare) {
        local compareString = "Type: " + typeof actual + ". " +
                              "Expected: '" + expected + "'. " +
                              "Got: '" + actual + "'.";
        if (message == null) {
            message = compareString;
        } else {
            message = message + ". " + compareString;
        }
    }
    if (typeof actual == "blob") {
        assertDeepEqual(expected.tostring(), actual.tostring(), message);
    } else {
        assertDeepEqual(expected, actual, message);
    }
}

function getConnectionManager(dummy = true, options = null) {
    if (dummy) {
        return DummyConnectionManager(options);
    } else {
        return ConnectionManager(options);
    }
}

class DummyConnectionManager {

    _connected = null;
    _onDisconnect = null;
    _onConnect = null;

    static VERSION = "3.1.0";

    function constructor(settings = {}) {
        _connected = true;
        
        local startBehavior = ("startBehavior"   in settings) ? settings.startBehavior   : CM_START_NO_ACTION;

        switch (startBehavior) {
            case CM_START_NO_ACTION:
                // Do nothing
                break;
            case CM_START_CONNECTED:
                // Start connecting if they ask for it
                imp.wakeup(0, connect.bindenv(this));
                break;
            case CM_START_DISCONNECTED:
                // Disconnect if required
                imp.wakeup(0, disconnect.bindenv(this));
                break;
        }
    }

    function isConnected() {
        return _connected;
    }

    function disconnect() {
        this._connected = false;
        _isFunc(_onDisconnect) && _onDisconnect(true);
    }

    function connect() {
        this._connected = true;
        _isFunc(_onConnect) && _onConnect();
    }

    function onDisconnect(handler, id) {
        _onDisconnect = handler;
    }

    function onConnect(handler, id) {
        _onConnect = handler;
    }

    function _isFunc(f) {
        return f && typeof f == "function";
    }
}

// Fix out-of-sync of the agent and device, if needed
if (DEVICE_ADDITIONAL_WAITING_TIME > 0 && !isAgentSide()) {
    imp.sleep(DEVICE_ADDITIONAL_WAITING_TIME);
}
if (AGENT_ADDITIONAL_WAITING_TIME > 0 && isAgentSide()) {
    imp.sleep(AGENT_ADDITIONAL_WAITING_TIME);
}
