import std/[asyncnet, net, asyncdispatch, strutils, sequtils, times, tables, strformat]
import db_connector/db_sqlite
import libsodium/sodium
import base58/bitcoin
import ./miner
import ../protocol

func getPeers(db: DbConn): seq[string] =
    for node in db.fastRows(sql"""SELECT * FROM peers"""):
        result.add(node[1])

func addPeer(db: DbConn, ip: string) =
    db.exec(
        sql"""
            INSERT INTO peers (ip) VALUES (?)
        """, ip
    )

let 
    nodeDb = open("node.db", "", "", "")

template knownNodes: seq[string] = getPeers(nodeDb)

proc hasSufficientFunds(db: DbConn, senderAddress: string, amount: int): bool =
    let dbResult = db.getRow(
        sql"""
            SELECT balance FROM ledger WHERE address = ?
        """, senderAddress
    )

    let balance = parseInt(dbResult[0])

    if balance >= amount:
        return true
    else: return false

proc getLastBlock(db: DbConn): tuple[id: int, hash: string] =
    let dbResult = db.getRow(
        sql"""
            SELECT blockId, blockHash FROM blocks WHERE blockId = (SELECT MAX(blockId) FROM blocks)
        """
    )
    result.id = parseInt dbResult[0]
    result.hash = dbResult[1]

proc newBlock(db: DbConn, sender, receiver: string, amount, nonce: int, previousHash, blockHash: string) =
    db.exec(
        sql"""
            INSERT INTO blocks (senderAddress, receiverAddress, amount, nonce, previousBlockHash, blockHash) VALUES (?, ?, ?, ?, ?, ?)
        """, sender, receiver, amount, nonce, previousHash, blockHash
    )

proc newBlock*(db: DbConn, newBlock: Block) =
    newBlock(db, newBlock.sender, newBlock.receiver, newBlock.amount, newBlock.nonce, newBlock.previousHash, newBlock.blockHash)


proc sendMoney(db: DbConn, sender, receiver: string, amount: int) =
    db.exec(sql"BEGIN")
    db.exec(
        sql"""
            UPDATE ledger SET balance = (balance - ?) WHERE address = ? 
        """, amount, sender
    )

    db.exec(
        sql"""
            UPDATE ledger  SET balance = (balance + ?) WHERE address = ?
        """, amount, receiver
    )

    db.exec(sql"COMMIT")

proc withoutSignature(data: string): string =
    for line in data.splitLines:
        if line.split()[0].strip.toLowerAscii != "signature":
            result.add(line & "\n")

proc parseData(data: string): Table[string, string] =
    #data is expected to be key-value pairs
    let rows = data.strip.split('\n')
    if rows.len > 0:
        for row in rows:
            let cols = row.split().mapIt(it.strip)
            result[cols[0]] = cols[1]


func verify(senderAddress, msg, signature: string): bool =
    let decrypt = cryptoSignOpen(senderAddress.toPublicKey, decode(signature))
    # debugecho decrypt
    # debugecho "-------------------------"
    # debugecho msg
    # debugecho "-------------------------"
    if decrypt.strip == msg.strip:
        return true

proc broadcastBlock(nodes: seq[string], newBlock: Block) = 
    let networkSocket = newSocket()
    for node in nodes:
        # networkSocket.connect(node, protocolPort)
        networkSocket.connect(node, protocolPort)
        networkSocket.send(broadcastHeader(len($newBlock)) & $newBlock)

proc handleCommand(address: string, command: Command, data: string): string =
    case command:
        of SYNC: #send node latest chain state
            let 
                chainState = readfile("node.db")
                networkSocket = newSocket()
            
            networkSocket.connect(address, protocolPort)
            networkSocket.send(syncHeader(len(chainState)) & chainState)
            result = "SYNCED " & address & " WITH THE LATEST BLOCKCHAIN AS OF " & $now() & "\n"

        of BROADCAST: #ignore broadcasts for now
            result = "RECEIVED BROADCAST FOR NEW TRANSACTION BUT WILL IGNORE FOR NOW\n"

        of TRANSACTION: #receive and process new transaction on the chain
            let
                parsedData = data.parseData()
                signature = parsedData.getOrDefault("signature", "")
                senderAddress = parsedData.getOrDefault("sender", "")
                receiverAddress = parsedData.getOrDefault("receiver", "")
                amount = if parsedData.hasKey("amount"): parseInt parsedData["amount"] else: 0
                msg = data.withoutSignature()
            #[
                First make sure the signature is legit
                Then make sure the sender has enough money to send
                Then check the last block id and make the block id of this one +1
                Then add the nonce and start mining, mining will be done by one binary
                When new block is mined, broadcast to other blocks
            ]#

            result = "PROCESSING TRANSACTION OF " & $amount & " SHITCOINS FROM: " & senderAddress & " TO: " & receiverAddress & "\n"
            if senderAddress.verify(msg, signature):
                echo "VERIFIED SENDER"
                if nodeDB.hasSufficientFunds(senderAddress, amount):
                    echo "SENDER HAS SUFFICIENT FUNDS"
                    echo "PROCEED TO MINING STAGE"
                    let (lastBlockId, previousHash) = nodeDb.getLastBlock()
                    let newBlock = mine(lastBlockId+1, senderAddress, receiverAddress, amount, previousHash)
                    echo "MINED NEW BLOCK ", newBlock.repr
                    result.add(&"MINING FOR TRANSACTION: `{amount} SHITCOINS FROM {senderAddress} TO {receiverAddress}` COMPLETED WITH NONCE={newBlock.nonce}\n")
                    knownNodes.broadcastBlock(newBlock)
                    nodeDb.newBlock(newBlock)
                    nodeDB.sendMoney(senderAddress, receiverAddress, amount)
                else:
                    result.add("INSUFFICIENT FUNDS: " & senderAddress & " DOES NOT HAVE UP TO " & $amount & " SHITCOINS\n")
            else:
                result.add("INVALID SIGNATURE: seems like " & senderAddress & " DID NOT SIGN THIS TRANSACTION \n")


proc parseHeader(shitHeader: string): tuple[protocolName, version: string, command: Command, dataLen: int] =
    let data = shitHeader.toLowerAscii.split().mapIt(it.strip) #make lowercase, split by whitespace and remove extraspaces

    if data.len == 4:
        result = (data[0], data[1], parseEnum[Command] data[2], parseInt data[3])
    

proc handleClient(incomingClient: AsyncSocket) {.async.} =
    echo "NEW CLIENT CONNECTED"
    let (incomingClientIp, _) = incomingClient.getLocalAddr
    if incomingClientIp notin knownNodes:
        nodeDb.addPeer(incomingClientIp)

    while incomingClient.isClosed.not:
        try:
            let shitHeader = await incomingClient.recvLine()
            let (protocol, version, command, dataLen) = shitHeader.parseHeader()
            if protocol == protocolName.toLowerAscii and isSupportedVersion(version):
                let
                    data = await incomingClient.recv(dataLen)
                    response = handleCommand(incomingClient.getLocalAddr[0], command, data)
                await incomingClient.send(response)
            else:
                await incomingClient.send("YOU CONNECTED TO THE BLOCKCHAIN BUT YOUR COMMANDS ARE INVALID\n")

        except Exception as e:
            echo "EXCEPTION OCCURED: ", e.msg, " ", e.getStackTrace()
            # quit(69)
            await incomingClient.send("YOU CONNECTED TO THE BLOCKCHAIN BUT YOUR COMMAND(s) FAILED\n")

proc nodeServer() {.async.} = 
    let node = newAsyncSocket()
    node.setSockOpt(OptReuseAddr, true)
    node.bindAddr(protocolPort)
    node.listen()

    while true:
        let incomingClient = waitfor node.accept()
        asyncCheck handleClient(incomingClient)

when isMainModule:
    asyncCheck nodeServer()
    runForever()
