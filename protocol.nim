import net, strformat
import base58/bitcoin

const 
    protocolName* = "ShitP2P"
    protocolVersion* = "0.0.1"
    protocolPort* = Port(2005)


type 
    BlockChainNode* = object
        ip*: string

    Command* = enum
        SYNC = "sync"
        BROADCAST = "broadcast"
        TRANSACTION = "transaction"

    Block* = object
        blockId*: int
        sender*: string
        receiver*: string
        amount*: int
        nonce*: int
        previousHash*: string
        blockHash*: string

proc isSupportedVersion*(version: string):  bool =
    if version == protocolVersion:
        return true
    else: return false

proc toBlockChainAddress*(pk: string): string =
    result = encode(pk)

proc toPublicKey*(address: string): string =
    result = decode(address)

func prepareHeader(command: Command, msgLength: int): string =
    result = &"{protocolName} {protocolVersion} {command} {msgLength}\n"

template transactionHeader*(len: int): string = prepareHeader(TRANSACTION, len)
template broadcastHeader*(len: int): string = prepareHeader(BROADCAST, len)
template syncHeader*(len: int): string = prepareHeader(SYNC, len)