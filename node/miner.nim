import strformat
import checksums/sha2

import ../protocol

proc mine*(blockId: int, senderAddress, receiverAddress: string, amount: int, previousHash: string): Block = 
    #Mining on the shit-blockchain means that the hash must start with 4 zeroes
    var 
        nonce: int
        blockHash: string

    while true:
        var sha256Hasher = initSha_256()
        let data = &"blockId {blockId}\nsender {senderAddress}\nreceiver {receiverAddress}\namount {amount}\n previousHash {previousHash}\nnonce {nonce}\n"
        sha256Hasher.update(data)
        blockHash = $(sha256Hasher.digest)
        if blockHash[0..3] != "0000":
            inc nonce
        else:
            break

    result = Block(blockId: blockId, sender: senderAddress, receiver: receiverAddress, amount: amount, nonce: nonce, previousHash: previousHash, blockHash: blockHash)

when isMainModule: #mine the genesis block
    import ./node
    import db_connector/db_sqlite

    let 
        blockId = 1
        senderAddress = ""
        genesisAddress = "FAYKnZ5g733SHm5ouBsRSnKWhaUsZqmZynNQUsJnxsFg"
        amount = 100
        previousHash = ""
        
    let 
        genesisBlock = mine(blockId, senderAddress, genesisAddress, amount, previousHash)
        nodeDb = open("./node.db", "", "", "")

    newBlock(nodeDB, genesisBlock)