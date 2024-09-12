IEndpoint - Endpoints (the interface for interacting with LayerZero) exist as immutable smart contracts on each chain LayerZero supports. These are non-upgradeable and cannot be changed by any party, providing a safe and predictable interface to interact with. Every piece of core protocol code is non-upgradable

LayerZero is a generalized data messaging protocol that describes itself as an “omni-chain” solution. It is designed to carry lightweight messages across chains via gas-efficient, non-upgradeable smart contracts. Most existing cross-chain solutions employ models that rely on bridges or validators, which come with trade-offs in terms of security, 
decentralization, or gas costs.

LayerZero deploys endpoint (smart contracts) on each chain it supports. These endpoints are non-upgradeable and cannot be changed by any party, providing a safe and predictable interface to interact with. Oracles verifies that a transaction has occured on the source chain, and relayer sends the message to the destination chain.

For LayerZero v2, the protocol is immutable(last forever), permissionless(anyone can deploy), and censorship-resistant(enforce on how transactions are ordered).

Endpoint - core of the LayerZero protocol, they manage security configurations and sed/receive messages.

Relayer - off-chain entity responsible for transporting the data between the source and destination chains. Main responsibility is to observe the source chain, pick up the message/data that needs to be relayed and pass it to the destination chain.

LayerZero standards include how omnichain smart contracts are written, how data packets are structured, and how logic is composed.

Message Packet requires nonce, srcChainId, sender address, dstChainId, recipient address, unique identifier and message payload. The nonce, source/destination IDs and unique identifier prevent replay attacks and misrouting, while also helping track the message across chains. The payload field carries the actual information or command that needs to be carried out on the destination chain. With this information correctly formatted, any generic message can be passed between chains, allowing for the transfer of data, assets, and/or external contract calls.

Infrastructure - Anybody can run the entities necessary to both verify and execute transactions. 
- Decentralised Verifier Networks: verify cross-chain messages. Currently, 15+ DVNs are available, including DVNs run by Google Cloud and Polyhedra’s zklight client running DVNs and adapter DVNs for Axelar and CCIP.
- Executors: Executors ensure the smooth execution of a message on the destination chain by offering gas abstraction to the end-user. Executors do this by quoting end-users on the source chain in the source chain gas token while executing the transaction automatically on the destination chain. 

v1 vs v2
- Decoupling execution from verification: executor is separated from the verification process.
- X of Y of N: This modular approach to verification empowers applications to neither overpay nor underpay for security, depending on their use case
- Horizontal Composability: With horizontal composability, each leg of a transaction is saved locally on the destination chain. 
- Unordered Delivery: V2 allows developers to choose whether to execute transactions in order or not.

Deep dive into LayerZero v2: [https://medium.com/layerzero-official/layerzero-v2-deep-dive-869f93e09850]

LayerZero relies upon two off-chain entities, an Oracle and a Relayer, to pass messages between the endpoints found on different domains. 



