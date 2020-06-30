# Onewire 1.0.1 #

The Onewire library provides a means to interact with 1-Wire&reg; devices connected to an imp via UART. For more information on connecting 1-Wire devices this way, see [**Implementing A 1-Wire Bus On The imp**’**](https://developer.electricimp.com/resources/onewire).

The library provides a means to enumerate all of the 1-Wire devices connected to the host imp, and to communicate with any one of them. It also provides methods for the five key 1-Wire bus commands.

**To include this library in your project, add**

```
#require "Onewire.class.nut:1.0.1"
```

**at the top of your device code**

## Class Usage ##

### Constructor: Onewire(*impUart[, debug]*) ###

To instantiate a new Onewire object, just pass the imp [UART bus object](https://developer.electricimp.com/api/hardware/uart) you are using to drive your 1-Wire device(s). This bus should **not** be pre-configured; the class will apply two separate configuations &ndash; one for testing the bus, another for interacting with devices &ndash; while it is running.

Optionally, you may also pass a debugging flag: pass `true` to trigger debug log messages. This is `false` by default.

The constructor returns `null` if no UART bus is passed into it.

To begin using the 1-Wire device(s), you must call the library’s *init()* method.

```squirrel
#require "Onewire.class.nut:1.0.1"

ow <- Onewire(hardware.uart12);
```

## Class Methods ##

### init() ###

Call this method to prepare the 1-Wire/UART bus for use. It resets the bus and discovers whatever devices are connected to the bus.

The call returns `true` if the bus was successfully initialized, and `false` otherwise. If *init()* returns `false`, you can call *getErrorCode()* for more information.

```squirrel
local success = ow.init();

if (!success) {
    // Report error. Note if the Onewire object instantiated in
    // debug mode, the object will report errors
    local err = ow.getErrorCode();
    server.error(err.msg);
    return;
}

// Perform tasks on the 1-Wire bus...
```

### reset() ###

This method resets the 1-Wire bus and checks for connected devices, but does not enumerate them. It returns `true` if it detects a 1-Wire bus with one or more 1-Wire devices, `false` otherwise. It is implicitly called by [*init()*](#init).

If a call to *reset()* returns `false`, the error record relating to the reset failure can be read using the method *getErrorCode()*.

```squirrel
if (ow.reset()) {
    // Valid 1-Wire bus detected
    local temp = getTemperatureReading();
} else {
    // Display error code on LED
    local err = ow.getErrorCode();
    led.display("Error: " + err.msg);
}
```

### discoverDevices() ###

This method enumerates all the 1-Wire devices on the bus and returns an array of the discovered devices’ IDs. This array can be also accessed later using *getDevices()*. See the further methods below for means to access these devices. It is implicitly called by [*init()*](#init).

```squirrel
if (ow.reset()) {
    // Valid 1-Wire bus detected, so enumerate the bus
    devices = ow.discoverDevices();
    server.log(devices.len() + " devices discovered");
} else {
    // Display error code on LED
    local err = ow.getErrorCode();
    led.display("Error: " + err);
}
```

### getDeviceCount() ###

This method returns the number of 1-Wire devices on the bus. Note that this will be zero if you have not first called [*init()*](#init), or [*reset()*](#reset) and [*discoverDevices()*](#discoverDevices).

```squirrel
local success = ow.init();
if (success) {
    local n = ow.getDeviceCount();
    server.log("You have " + n + " 1-Wire devices connected");
}
```

### getDevices() ###

This method returns the class’ stored array containing the ID of each device on the 1-Wire bus that it has already discovered. If the returned array is empty, there are either no devices on the bus or your code has yet to enumerate them (using [*init()*](#init) or [*discoverDevices()*](#discoverDevices)).

```squirrel
local success = ow.init();
if (success) {
    local devices = ow.getDevices();
    if (devices.len() > 0) {
        foreach (index, device in devices) {
            server.log("Device " + index + " ID: " + device);
        }
    }
}
```

### getDevice(*deviceIndex*) ###

This method returns the ID of the device at index *deviceIndex* in the class’ list of discovered devices, or `null` if the value of *deviceIndex* is out of range.

```squirrel
local success = ow.init();
if (success) {
    local numberOfDevices = getDeviceCount();
    for (local i = 0 ; i < numberOfDevices ; i++) {
        local device = ow.getDevice(i);
        server.log("Device " + index + " ID: " + device);
    }
}
```

### getErrorCode() ###

This method returns an error table with the following keys:

| Key | Description |
| --- | --- |
| *code* | The error code (see below) |
| *msg* | Human-readable error message |

The code will be one of the following values:

| Code Value | Meaning |
| --- | --- |
| Onewire.READ_ERR_NO_DEVICES | No 1-Wire devices connected |
| Onewire.READ_ERR_NO_BUS     | No 1-Wire circuit detected  |

#### Example ####

```squirrel
if (ow.reset()) {
    // Valid 1-Wire bus detected
    local temp = getTemperatureReading();
} else {
    // Display error code on LED
    local err = ow.getErrorCode();
    server.error("1-Wire Error " + err.code + ": " + err.msg);
}
```

### writeByte(*byte*) ###

This method writes the supplied byte value to the 1-Wire bus. The value of *byte* is typically an integer; the method only writes the first eight bits of the 32-bit Squirrel integer.

#### Example ####

```squirrel
// Signal the sensor to take a reading
ow.reset();
ow.skipRom();
ow.writeByte(0x44);

// Give the sensor enough time for sampling
imp.sleep(0.8);

// Tell the sensor to transmit the reading
ow.reset();
ow.skipRom();
ow.writeByte(0xBE);
```

### readByte() ###

This method reads a eight bits of data from the 1-Wire bus and returns it as an integer.

#### Example ####

```squirrel
// Read the temperature
local tempLSB = ow.readByte();
local tempMSB = ow.readByte();
```

### skipRom() ###

This method writes the 1-Wire command ‘Skip ROM’ to the bus, which tells it to ignore a supplied device ID in the next transaction. It is intended to be used if there is only one device or to send subsequent commands to all devices.

#### Example ####

```squirrel
// Signal the sensor to take a reading
ow.reset();
ow.skipRom();
ow.writeByte(0x44);
```

### readRom() ###

This method writes the 1-Wire command ‘Read ROM’ to the bus: read a device’s ID. It is used when there is only one device on the bus.

### searchRom() ###

This method writes the 1-Wire command ‘Search ROM’ to the bus, to prepare it for device enumeration.

### matchRom() ###

This method writes the 1-Wire command ‘Match ROM’ to the bus. This indicates a specific device is to be selected and that the device’s ID will be the next 64 bits to be written.

#### Example ####

```squirrel
local devices = ow.getDevices();
foreach (index, device in devices) {
    // Run through the list of discovered devices, getting the temperature
    // if a given device is of the correct family number: 0x28 for BS18B20 sensor
    if (device[7] == 0x28) {
        ow.reset();

        // Issue 1-Wire MATCH ROM command to select device by ID
        ow.matchRom();

        // Write out the 64-bit ID from the 'device' array's eight bytes
        for (local i = 7 ; i >= 0 ; i--) {
            ow.writeByte(device[i]);
        }

        // Issue the DS18B20's READ SCRATCHPAD command (0xBE) to get temperature
        ow.writeByte(0xBE);

        // Read the temperature value from the sensor's RAM
        local tempLSB = ow.readByte();
        local tempMSB = ow.readByte();

        // Signal that we don't need any more data by resetting the bus
        ow.Reset();

        // Calculate the temperature from LSB and MSB
        local tempCelsius = ((tempMSB * 256) + tempLSB) / 16.0;
        server.log("The temperature is " + tempCelsius + "C");
    }
}
```

## License ##

The OneWire library is licensed under the MIT license.
