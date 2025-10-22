// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import "@arcologynetwork/concurrentlib/lib/multiprocess/Multiprocess.sol";
import "@arcologynetwork/concurrentlib/lib/commutative/U256Cum.sol";

contract MyMultiProcess {
    U256Cumulative sum=new U256Cumulative(0,100);
    Multiprocess mp = new Multiprocess(3);
    event QueryBalance(uint256 val);

    function add(uint256 rows,uint256 cols)public {
        for(uint i=0;i<rows;i++)
            mp.addJob(1000000000,0, address(this), abi.encodeWithSignature("increment(uint256)", cols)); // Will require about 1.5M gas
        mp.run();
        emit QueryBalance(sum.get());
    }

    // This function will be called in parallel by multiple processes
    function increment(uint256 cols) public {
        for(uint i=0;i<cols;i++){
            sum.add(1);
        }
    }
    
    function reset()public {
        uint256 n=sum.get();
        sum.sub(n);
        emit QueryBalance(sum.get());
    }
}