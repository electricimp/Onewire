class OneWire
{
  static version = [1,0,0];
  
  static READ_ERR_NO_DEVICES = "Error: No 1-Wire device connected.";
  static READ_ERR_NO_BUS = "Error: No 1-Wire circuit detected.";
  
  _ow = null;
  _currentId = null;
  _slaves = null;
  _nextDevice = 0;
  _readErrorReason = 0;
  _debugFlag = false;

  constructor (impUart = null, debug = false) {
    if (impUart == null) return null;
    _ow = impUart;
    _slaves = [];
    _currentId = [];
    _debugFlag = debug;
  }

  function init() {
    // Reset and test the bus; if it's good, enumerate the devices on the bus
    if (reset()) listSlaves();
    if (_debugFlag) server.log("1-Wire read error: " + _readErrorReason);
    return _readErrorReason;
  }

  function reset() {
    // Reset the 1-Wire bus and check for connected devices
    // Returns true only if there is at least one valid 1-Wire device connected
    // On error, a reason code is saved in _readErrorReason, and this can be
    // read using getErrorCode()
    _readErrorReason = 0;

    // Configure UART for 1-Wire RESET timing
    _ow.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS);
    _ow.write(0xF0);
    _ow.flush();
    local readVal = _ow.read();

    if (readVal == 0xF0) {
      // UART RX will read TX if there are no devices connected
    	_readErrorReason = 1;
    	if (_debugFlag) server.log(READ_ERR_NO_DEVICES);
    	return false;
    } else if (readVal == -1) {
      // A general UART read error - most likely nothing wired up
    	_readErrorReason = 2;
    	if (_debugFlag) server.log(READ_ERR_NO_BUS);
    	return false;
    } else {
    	// Switch UART to 1-Wire data speed timing
    	_readErrorReason = 0;
    	if (_debugFlag) server.log("Success: 1-Wire device(s) discovered.");
    	_ow.configure(115200, 8, PARITY_NONE, 1, NO_CTSRTS);
    	return true;
    }
  }

  function listSlaves() {
    // Enumerate the devices on the 1-Wire bus and store their unique 1-Wire IDs
    // in the slaves array
    _slaves = [];
    _currentId = [0,0,0,0,0,0,0,0];

    // Begin the enumeration at address 65
    _nextDevice = 65;
    while (_nextDevice > 0) {
      _nextDevice = _search(_nextDevice);
      _slaves.push(clone(_currentId));
    }
    if (_debugFlag) server.log(_slaves.len() + " 1-Wire device(s) discovered.");
  }

  function getDeviceCount() {
    // Returns the number of devices on the 1-Wire bus
    return _slaves.len();
  }

  function getDevice(deviceIndex) {
    // Returns a specific device’s ID
    eturn _slaves[deviceIndex];
  }

	function getDevices() {
		// Returns the array containing all the connected devices’ IDs
		return _slaves;
	}

  function getErrorCode() {
  	// Returns the current read error code; this is zero'd
  	// every time reset() is called
  	return _readErrorReason;
  }

  function writeByte(byte) {
    // Write a byte of data or a command to the 1-Wire bus
    for (local i = 0 ; i < 8 ; i++, byte = byte >> 1) {
      // Run through the bits in the byte, extracting the
      // LSB (bit 0) and sending it to the bus
      _readWriteBit(byte & 0x01);
    }
  }

  function readByte() {
    // Read a byte from the 1-Wire bus
    local byte = 0;
    for (local b = 0 ; b < 8 ; b++) {
      // Build up byte bit by bit, LSB first
			byte = (byte >> 1) + 0x80 * _readWriteBit(1);
    }
    return byte;
  }

	// 1-Wire command functions - these are single-byte standard commands
	// see https://electricimp.com/docs/resources/onewire/

  function skipRom() {
    // Ignore device ID(s)
    writeByte(0xCC);
  }

  function readRom() {
    // Read a device’s ID
    writeByte(0x33);
  }

  function searchRom() {
    // Begin enumerating IDs
    writeByte(0xF0);
  }

  function matchRom() {
    // Select a device with a specific ID
    // Next 64 bits to be written will be the known ID
    writeByte(0x55);
  }

  // *** PRIVATE FUNCTIONS: DO NOT CALL DIRECTLY ***

  function _readWriteBit(bit) {
    // Clock out a bit-as-a-byte value then immediately
    // clock in a byte-as-a-bit value and return it
    bit = bit ? 0xFF : 0x00;
    _ow.write(bit);
    _ow.flush();
    local returnVal = _ow.read() == 0xFF ? 1 : 0;
    return returnVal;
  }

  function _search(nextNode)
  {
    // Device enumeration support function. Progresses one step up the tree
    // from the current device, returning the next current device along.
    // Called by listSlaves()

    local lastForkPoint = 0;

    // Reset the bus and exit if no device found

    if (reset()) {
      // If there are 1-Wire device(s) on the bus - for which one_wire_reset()
      // checks - this function readies them by issuing the 1-Wire SEARCH command (0xF0)
      searchRom();

      // Work along the 64-bit ROM code, bit by bit, from LSB to MSB
      for (local i = 64 ; i > 0 ; i--) {
        local byte = (i - 1) / 8;

        // Read bit from bus
        local bit = _readWriteBit(1);

        // Read the next bit, the first's complement
        if (_readWriteBit(1)) {
          if (bit) {
            // If first bit is 1 too, this indicates no further devices
            // so put pointer back to the start and break out of the loop
            lastForkPoint = 0;
            break;
          }
        } else if (!bit) {
          // First and second bits are both 0
          if (nextNode > i || ((nextNode != i) && (_currentId[byte] & 1))) {
            // Take the '1' direction on this point
            bit = 1;
            lastForkPoint = i;
          }
        }

        // Write the 'direction' bit. If it's, say, 1, then all further
        // devices with a 0 at the current ID bit location will go offline
        _readWriteBit(bit);

        // Shift out the previous path bits, add on the msb side the new choosen path bit
        _currentId[byte] = (_currentId[byte] >> 1) + 0x80 * bit;
      }
    }

    // Return the last fork point for next search
    return lastForkPoint;
  }
}
