# MessageManager 2.4.0 #

MessageManager is framework for asynchronous bidirectional agent to device communication. It is the successor to [Bullwinkle](https://github.com/electricimp/Bullwinkle).

The library uses [ConnectionManager](https://github.com/electricimp/ConnectionManager) on the device side to receive notifications of connection and disconnection events, and to monitor connection status (ie. so that no attempt it made to send messages when the device is disconnected).

**To include this library in your project, add** `#require "MessageManager.lib.nut:2.4.0"` **at the top of your agent and device code.**

**Note** MessageManager is designed to run over reliable (ie. TCP/TLS) connections. Retries only occur in the case of dropped connections or lost packets, or if called manually from [*beforeSend()*](#mmanager_before_send) or [*beforeRetry()*](#mmanager_before_retry).

![Build Status](https://cse-ci.electricimp.com/app/rest/builds/buildType:(id:MessageManager_BuildAndTest)/statusIcon)

## API Overview ##

- [MessageManager](#mmanager) &mdash; The core library. It is used to add/remove message callbacks, and to send messages
    - [MessageManager.send()](#mmanager_send) &mdash; Sends the data message
    - [MessageManager.on()](#mmanager_on) &mdash; Sets the callback which will be executed when
    a message with the specified name is received (name-specific or generic)
    - [MessageManager.defaultOn()](#mmanager_defaulton) &mdash; Sets the generic callback, which will be executed when a message doesn’t match any of the name-specific callbacks
    - [MessageManager.beforeSend()](#mmanager_before_send) &mdash; Sets the callback which will be called
    before a message is sent
    - [MessageManager.beforeRetry()](#mmanager_before_retry) &mdash; Sets the callback which will be called
    before a message is retried
    - [MessageManager.onFail()](#mmanager_on_fail) &mdash; Sets the callback which will be called when an error occurs
    - [MessageManager.onTimeout()](#mmanager_on_timeout) &mdash; Sets the callback which will be called when an message
    times out
    - [MessageManager.onAck()](#mmanager_on_ack) &mdash; Sets the callback which will be called on the message acknowledgement
    - [MessageManager.onReply()](#mmanager_on_reply) &mdash; Sets the callback which will be called when a sent message receives a reply
    - [MessageManager.getPendingCount](#mmanager_get_pending_count) &mdash; Returns the overall number of pending messages
    (either waiting for acknowledgement or waiting in the retry queue)
- [MessageManager.DataMessage](#mmanager_data_message) &mdash; The data message object, consisting of the payload
to be send over the air and meta-information used to control the message lifecycle
    - [MessageManager.DataMessage.onFail()](#mmanager_data_message_on_fail) &mdash; Sets the message-local
    callback to be executed when an error occurs
    - [MessageManager.DataMessage.onTimeout()](#mmanager_data_message_on_timeout) &mdash; Sets the message-local
    callback to be executed when a transmission times out
    - [MessageManager.DataMessage.onAck()](#mmanager_data_message_on_ack) &mdash; Sets the message-local
    callback to be executed when a sent message is acknowledged
    - [MessageManager.DataMessage.onReply()](#mmanager_data_message_on_reply) &mdash; Sets the message-local
    callback to be executed when a sent message receives a reply

## MessageManager Usage ##

<div id="mmanager"><h3>Constructor: MessageManager(<i>[options]</i>)</h3></div>

Calling the MessageManager constructor creates a new MessageManager instance. An optional
table can be passed into the constructor (as *options*) to override default behaviours. *options* can contain any of the following keys:

| Key | Data&nbsp;Type | Description |
| ---- | --- | --- |
| *debug* | Boolean | The flag that enables debug library mode, which turns on extended logging. Default: `false` |
| *retryInterval* | Integer | Changes the default timeout parameter passed to the retry method. Default: 0s |
| *messageTimeout* | Integer | Changes the default timeout required before a message is considered failed (to be acknowledged or replied to). Default: 10s |
| *autoRetry* | Boolean | If set to `true`, MessageManager will automatically continue to retry sending a message until *maxAutoRetries* has been reached when no [onFail()](#mmanager_on_fail) callback is supplied. Please note that if *maxAutoRetries* is set to 0, *autoRetry* will have no limit to the number of times it will retry. Default: `false` |
| *maxAutoRetries* | Integer | Changes the default number of automatic retries to be performed by the library. After this number is reached the message will be dropped. Please note that the message will automatically be retried if there is no [onFail()](#mmanager_on_fail) callback registered by the user. Default: 0 |
| *connectionManager* | [ConnectionManager](https://github.com/electricimp/ConnectionManager) | Optional instance of the [ConnectionManager](https://github.com/electricimp/ConnectionManager) library that helps MessageManager track connectivity status. Default: `null` |
| *nextIdGenerator* | Function | User-defined callback that generates the next message ID. The function has no parameters. Default: `null` |
| *onPartnerConnected* | Function | Sets the callback to be triggered when the partner is known to be connected. The callback’s signature is: *callbackName(reply)*, where *reply(data)* is a callback to respond to the “connected” event. Default: `null` |
| *onConnectedReply* | Function | Sets the callback to be triggered when the partner responds to the connected status. The callback’s signature is: *callbackName(response)*, where *response* is the response data. Default: `null` |
| *maxMessageRate* | Integer | Maximum message send rate, which defines the maximum number of messages the library allows to send per second. If the application exceeds the limit, the *onFail* callback is triggered. Default: 10 messages/s<br />**Note** please don’t change the value unless absolutely necessary |
| *firstMessageId* | Integer | Initial value for the auto-incrementing message ID. Default: 0 |

#### Examples ####

```squirrel
// Initialize using default settings
local mm = MessageManager();
```

```squirrel
// Create ConnectionManager instance
local cm = ConnectionManager({
    "blinkupBehavior": CM_BLINK_ALWAYS,
    "stayConnected": true
});

imp.setsendbuffersize(8096);

// MessageManager options
local options = { "debug": true,
                  "retryInterval": 15,
                  "messageTimeout": 2,
                  "autoRetry": true,
                  "maxAutoRetries": 10,
                  "connectionManager": cm
};

local mm = MessageManager(options);
```

<div id="mmanager_send"><h3>MessageManager.send(<i>name[, data][, callbacks][, timeout][, metadata]</i>)</h3></div>

This method sends a named message to the partner side and returns the [MessageManager.DataMessage](#mmanager_data_message) object created. The *data* parameter can be a basic Squirrel type (`1`, `true`, `"A String"`) or more complex data structures such as an array or table, but it must be [a serializable Squirrel value](https://developer.electricimp.com/resources/serialisablesquirrel).

```squirrel
mm.send("lights", true);   // Turn on the lights
```

*callbacks* is a table containing the local message event callback functions. The library uses the key name to determine which callback-registration method to use. For example, if the table contains the key *onAck*, the key’s value (which should be a function) will be passed into *MessageManager.DataMessage.onAck()* in order to register it as the acknowledgement callback.

| Key | Registration&nbsp;Method | Description | 
| --- | --- | --- |
| *onAck* | [MessageManager.DataMessage.onAck](#mmanager_data_message_on_ack) | Acknowledgement |
| *onFail*| [MessageManager.DataMessage.onFail](#mmanager_data_message_on_fail) | Failure |
| *onReply*| [MessageManager.DataMessage.onReply](#mmanager_data_message_on_reply) | Reply | 
| *onTimeout*| [MessageManager.DataMessage.onTimeout](#mmanager_data_message_on_timeout) | Timeout |

**Note**  Message-local callbacks override the global ones, ie. if a message-local callback is triggered, the global one, if set, will not be executed.

<div id="mmanager_on"><h4>MessageManager.on(<i>messageName, callback</i>)</h4></div>

If the *messageName* parameter’s argument is not `null`, this method sets the name-specific message callback. Otherwise it uses the generic message callback. The generic message callback captures any messages not handled by any name-specific callback. The callback function takes two parameters: *message* (the message) and *reply* (a function that can be called to reply to the message).

#### Example ####

```squirrel
// Set a name-specific message callback
mm.on("lights", function(message, reply) {
    led.write(message.data);
    reply("Got it!");
});

// Set a generic message callback
mm.on(null, function(message, reply) {
    log(message.data);
    reply("Got it!");
});
```

<div id="mmanager_defaulton"><h3>MessageManager.defaultOn(<i>callback</i>)</h3></div>

This method sets a callback which is executed only for those messages that are not matched and handled by any name-specific callbacks set via [MessageManager.on](#mmanager_on). The callback function takes two parameters: *message* (the message) and *reply* (a function that can be called to reply to the message).

#### Example ####

```squirrel
// Set a generic message callback
mm.defaultOn(function(message, reply) {
    log(message.data);
    reply("Got it!");
});
```

<div id="mmanager_before_send"><h3>MessageManager.beforeSend(<i>callback</i>)</h3></div>

This method sets the callback which will be called *before* a message is sent. The callback has the following parameters:

| Parameter | Description |
| --- | --- |
| *message* | An instance of [DataMessage](#mmanager_data_message) to be sent |
| *enqueue* | A function with no parameters which appends the message to the retry queue for later processing |
| *drop* | A function which disposes of the message. It takes two optional parameters: *silently*, which defaults to `true` and which governs whether the disposal takes place silently or through the *onFail* callbacks, and *error* which if *silently* is `false`, specifies the error message to be provided to the *onFail* callback |

The *enqueue* and *drop* functions must be called synchronously, if they are called at all.

#### Example ####

```squirrel
mm.beforeSend(
    function(msg, enqueue, drop) {
        if (runningOutOfMemory()) {
            drop();
        }

        if (needToPreserveMessageOrder() && previousMessagesFailed()) {
            enqueue();
        }
    }
);
```

<div id="mmanager_before_retry"><h3>MessageManager.beforeRetry(<i>callback</i>)</h3></div>

This method sets the callback for retry operations. It will be called before the library attempts to re-send the message and has the following parameters:

| Parameter | Description |
| --- | --- |
| *message* | An instance of [DataMessage](#mmanager_data_message) to be re-sent |
| *skip* | A function with a single parameter, *duration*, which postpones the retry attempt and leaves the message in the retry queue for the specified amount of time. If *duration* is not specified, it defaults to the *retryInterval* provided for *MessageManager* [constructor](#mmanager) |
| *drop* | A function which disposes of the message. It takes two optional parameters: *silently*, which defaults to `true` and which governs whether the disposal takes place silently or through the *onFail* callbacks, and *error* which if *silently* is `false`, specifies the error message to be provided to the *onFail* callback |

The *skip* and *drop* functions must be called synchronously, if they are called at all.

#### Example ####

```squirrel
mm.beforeRetry(
    function(msg, skip, drop) {
        if (runningOutOfMemory()) {
            drop();
        }

        if (needToWaitForSomeReasonBeforeRetry()) {
            skip(duration);
        }
    }
);
```

<div id="mmanager_on_fail"><h3>MessageManager.onFail(<i>callback</i>)</h3></div>

This method sets the function to be called when a message error occurs. The callback has the following parameters:

| Parameter | Description |
| --- | --- |
| *message* | An instance of [DataMessage](#mmanager_data_message) that caused the error |
| *reason* | The error description string |
| *retry* | A function that can be invoked to retry sending the message in a specified period of time. This function must be called synchronously, if it is called at all. It takes one parameter, *interval*. If there is no *interval* parameter specified, the *retryInterval* value provided for *MessageManager* [constructor](#mmanager) is used. If the function is not called, the message will expire |

#### Example ####

```squirrel
mm.onFail(
    function(msg, error, retry) {
        // Always retry to send the message
        retry();
    }
);
```

<div id="mmanager_on_timeout"><h3>MessageManager.onTimeout(<i>callback</i>)</h3></div>

This method sets the callback to be executed when a message timeout occurs. The callback has the following parameters:

| Parameter | Description |
| --- | --- |
| *message* | An instance of [DataMessage](#mmanager_data_message) that caused the timeout |
| *wait* | A function which resets the acknowledgement timeout for the message, which means the message will not raise a timeout error for the interval of time specified by the function’s *interval* parameter. This function must be called synchronously |
| *fail* | A function which makes the message fall through the *onFail* callbacks |

If neither *wait* nor *fail* are called, the message will expire.

#### Example ####

```squirrel
mm.onTimeout(
    function(msg, wait, fail) {
        if (isStillValid(msg)) {
            wait(10);
        } else {
            // Fail otherwise
            fail();
        }
    }
);
```

<div id="mmanager_on_ack"><h3>MessageManager.onAck(<i>callback</i>)</h3></div>

This method sets the callback to be executed when the message’s receipt is acknowledged. The callback has the following parameters:

| Parameter | Description |
| --- | --- |
| *message* | An instance of [DataMessage](#mmanager_data_message) that was acknowledged |

#### Example ####

```squirrel
mm.onAck(
    function(msg) {
        // Just log the ACK event
        server.log("ACK received for " + msg.payload.data);
    }
);
```

**Note** A message is only acknowledged if the receiving party has defined a callback for this message.

<div id="mmanager_on_reply"><h3>MessageManager.onReply(<i>callback</i>)</h3></div>

This method sets the callback to be executed when the message is replied to. The callback has the following parameters:

| Parameter | Description |
| --- | --- |
| *message* | An instance of [DataMessage](#mmanager_data_message) that was replied to |
| *response* | The response from the partner |

#### Example ####

```squirrel
mm.onReply(
    function(msg, response) {
        processResponseFor(msg.payload.data, response);
    }
);
```

**Note** Setting the callback doesn’t necessarily imply that the other side must reply to the message. It just registers a function which is executed if and when the message is replied to.

<div id="mmanager_get_pending_count"><h3>MessageManager.getPendingCount()</h3></div>

This method returns the overall number of pending messages (either waiting for acknowledgement or waiting in the retry queue).

#### Example ####

```squirrel
if (mm.getPendingCount() < SOME_MAX_PENDING_COUNT) {
    mm.send("temp", temp);
} else {
    // Do something else
}
```

<div id="mmanager_data_message"><h3>MessageManager.DataMessage</h3></div>

MessageManager.DataMessage instances are not intended to be created by users manually &mdash; they are always returned from the [MessageManager.send()](#mmanager_send) method.

<div id="mmanager_data_message_on_fail"><h3>MessageManager.DataMessage.onFail()</h3></div>

This method sets a message-local version of the [MessageManager.onFail()](#mmanager_on_fail) callback.

<div id="mmanager_data_message_on_timeout"><h3>MessageManager.DataMessage.onTimeout()</h3></div>

This method sets a message-local version of the [MessageManager.onTimeout()](#mmanager_on_timeout) callback.

<div id="mmanager_data_message_on_ack"><h3>MessageManager.DataMessage.onAck()</h3></div>

This method sets a message-local version of the [MessageManager.onAck()](#mmanager_on_ack) callback.

<div id="mmanager_data_message_on_reply"><h3>MessageManager.DataMessage.onReply()</h3></div>

This method sets a message-local version of the [MessageManager.onReply()](#mmanager_on_reply) callback.

## Other Usage Examples ##

### Integration with [ConnectionManager](https://github.com/electricimp/ConnectionManager) ###

```squirrel
// Device code

#require "ConnectionManager.lib.nut:3.0.0"
#require "MessageManager.lib.nut:2.4.0"

local cm = ConnectionManager({
    "blinkupBehavior": CM_BLINK_ALWAYS,
    "stayConnected": true
});

// Set the recommended buffer size
// (see https://github.com/electricimp/ConnectionManager for details)
imp.setsendbuffersize(8096);

local config = {
    "messageTimeout": 2,
    "connectionManager": cm
};

local counter = 0;
local mm = MessageManager(config);

mm.onFail(
    function(msg, error, retry) {
        server.log("Error occurred: " + error);
        retry();
    }
);

mm.onReply(
    function(msg, response) {
        server.log("Response for " + msg.payload.data + " received: " + response);
    }
);

function sendData() {
    mm.send("name", counter++);
    imp.wakeup(1, sendData);
}

sendData();
```

```squirrel
// Agent code

#require "MessageManager.lib.nut:2.4.0"

local mm = MessageManager();

mm.on("name", function(message, reply) {
    server.log("Message received: " + message.data);
    reply("Got it!");
});
```

## License ##

This library is licensed under the [MIT License](./LICENSE).
