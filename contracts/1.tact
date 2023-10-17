import "@stdlib/deploy";
message Add {
  queryId: Int as uint8;
  number: Int as uint8;
}

message Subtract {
  queryId: Int as uint8;
  number: Int as uint8;
}

contract Task1 with Deployable {
    counter: Int as int8;

    init() {
      self.counter = 0;
    }

    receive(msg: Add) {
      self.counter = self.counter + msg.number;
    }
    
    receive(msg: Subtract) {
      self.counter = self.counter - msg.number;
    }

    get fun counter(): Int {
      return self.counter;
    }
}

