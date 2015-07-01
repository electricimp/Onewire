# Onewire

The Onewire class library provides a means to interact with 1-Wire devices connected to an imp via a UART bus. For more information on connecting 1-Wire devices this way, see [‘Implementing a 1-Wire Bus on the imp’](https://electricimp.com/docs/resources/onewire/).

The class provides a means to enumerate all the 1-Wire devices connected to the host imp, and to communicate with any one of them. It provides methods for the five key 1-Wire bus commands.

**To add this library to your project, add** `#require "Onewire.class.nut:1.0.0"` **to the top of your device code**

## Class Usage

### Constructor: Onewire(*impUart,* [*debug*])

To instantiate a new Onewire object, just pass the imp [UART bus object](https://electricimp.com/docs/api/hardware/uart/) you are using to drive your 1-Wire device(s). This bus should **not** be pre-configured; the class will apply two separate configuations &ndash; one for testing the bus, another for interacting with devices &ndash; while it is running.

Optionally, you may also pass a debugging flag: pass `true` to trigger debug log messages. This is `false` by default.

The constructor returns `null` if no UART bus is passed into it.

```squirrel
#require "Onewire.class.nut:1.0.0"

ow <- Onewire(hardware.uart12);
```

## Class Methods

### init()

Call this method to prepare the 1-Wire/UART bus for use. It resets the bus and discovers the bus’ devices.

It returns 0 for success, or an error code to indicate a bus-read failure:

| Code                        | Meaning                      |
| --------------------------- | ---------------------------- |
| Onewire.READ_ERR_NO_DEVICES | No 1-Wire devices connected. |
| Onewire.READ_ERR_NO_BUS     | No 1-Wire circuit detected.  |

```squirrel
local success = ow.init();
if (!success) {
    // Report error. Note if the Onewire object instantiated in
    // debug mode, the object will report errors
    local err = ow.getErrorCode();
    if (err == Onewire.READ_ERR_NO_DEVICES) {
        server.log("No devices found on 1-Wire bus.");
    }
    if (err == Onewire.READ_ERR_NO_BUS) {
        server.log("Could not find 1-Wire bus.")
    }
    server.log("1-Wire error.");
    return;
}
// Perform tasks on the 1-Wire bus...

```

### reset()

This method reset the 1-Wire bus and checks for connected devices, but does not enumerate them. It returns `true` if it detects a 1-Wire bus with one or more 1-Wire devices, `false` otherwise. It is implicitly called by *init()*.

*reset()* clears and, in it encounters an error, an internal error record. If a call to *reset()* returns `false`, this error record can be read using the method *getErrorCode()*.

```squirrel
if (ow.reset()) {
    // Valid 1-Wire bus detected
    local temp = getTemperatureReading();
} else {
    // Display error code on LED
    local err = ow.getErrorCode();
    led.display("Error: " + err);
}
```

### discoverDevices()

This method enumerates all the 1-Wire devices on the bus, storing connected devices’ unique IDs internally. See the further methods below for means to access these devices. It is implicitly called by [*init()*](#init).

```squirrel
if (ow.reset()) {
    // Valid 1-Wire bus detected, so enumerate the bus
    devices = ow.discoverDevices();
    server.log(devices.len() + " devices discovered!");
} else {
    // Display error code on LED
    local err = ow.getErrorCode();
    led.display("Error: " + err);
}
```

### getDeviceCount()

This method returns the number of 1-Wire devices on the bus. Note that this will be zero if you have not first called [*init()*](#init) or [*reset()*](#reset) and [*discoverDevices()*](#listdevices).

```squirrel
local success = ow.init();
if (success) {
    local n = ow.getDeviceCount();
    server.log("You have " + n + " 1-Wire devices connected to your imp.");
}
```

### getDevices()

This method returns an array in which the ID of each device on the 1-Wire bus is stored. If the returned array is empty, there are either no devices on the bus or your code has yet to enumerate them (using [*init()*](#init) or [*discoverDevices()*](#listdevices)).

```squirrel
local success = ow.init();
if (success) {
    local devices = ow.getDevices();
    if (devices.len() > 0) {
        foreach (index, device in devices) {
            server.log("Device " + index + ": " + device);
        }
    }
}
```

### getDevice(*deviceIndex*)

This method returns the ID of the device at index *deviceIndex* in the list, or `null` if the value of *deviceIndex* is out of range.

```squirrel
local success = ow.init();
if (success) {
    local numDevs = getDeviceCount();
    for (local i = 0 ; i < numDevs ; i++) {
        local device = ow.getDevice();
        server.log("Device " + index + ": " + device);
    }
}
```

### getErrorCode()

This method returns an error code (or 0 if there was no error) from the last bus reset. See [*reset()*](#reset), above, for example code.

### writeByte(*byte*)

This method writes the supplied byte value to the 1-Wire bus. The value of *byte* is tyically an integer; the method only writes the first eight bits of the 32-bit Squirrel integer.

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

### readByte()

This method reads a eight bits of data from the 1-Wire bus and returns it as an integer.

```squirrel
// Read the temperature
local tempLSB = onew.readByte();
local tempMSB = onew.readByte();
```

### skipRom()

This method writes the 1-Wire command ‘Skip ROM’ to the bus, which tells it to ignore a supplied device ID in the next transaction. It is intended to be used if there is only one device or to send subsequent commands to all devices.

```squirrel
// Signal the sensor to take a reading
ow.reset();
ow.skipRom();
ow.writeByte(0x44);
```

### readRom()

This method writes the 1-Wire command ‘Read ROM’ to the bus: read a device’s ID. It is used when there is only one device on the bus.

### searchRom()

This method writes the 1-Wire command ‘Search ROM’ to the bus, to prepare it for device enumeration.

### matchRom()

This method writes the 1-Wire command ‘Match ROM’ to the bus. This indicates a specific device is to be selected and that the device’s ID will be the next 64 bits to be written.

```squirrel
local devices = ow.getDevices();
foreach (index, device in devices) {
    // Run through the list of discovered devices, getting the temperature
    // if a given device is of the correct family number: 0x28 for BS18B20
    if (device[7] == 0x28) {
        ow.reset();

        // Issue 1-Wire MATCH ROM command to select device by ID
        ow.matchRom();

        // Write out the 64-bit ID from the array's eight bytes
        for (local i = 7 ; i >= 0 ; i--) {
            ow.writeByte(device[i]);
        }

        // Issue the DS18B20's READ SCRATCHPAD command (0xBE) to get temperature
        ow.riteByte(0xBE);

        // Read the temperature value from the sensor's RAM
        local tempLSB = ow.eadByte();
        local tempMSB = ow.readByte();

        // Signal that we don't need any more data by resetting the bus
        onewireReset();

        // Calculate the temperature from LSB and MSB
        local tempCelsius = ((tempMSB * 256) + tempLSB) / 16.0;
        server.log("The temperature is " + tempCelsius + "C");
    }
}
```
