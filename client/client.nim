import strformat, net, strutils
import db_connector/db_sqlite
import libsodium/sodium
import base58/bitcoin
import ../protocol

let 
    networkSocket = newSocket()


type 
    Transaction = object
        sender: string #sender address
        receiver: string #receiver address
        amount: int
        signature: string


func getNodes(db: DbConn): seq[BlockChainNode] =
    for node in db.fastRows(sql"""SELECT * FROM nodes"""):
        let blockNode = BlockChainNode(ip: node[1])
        result.add(blockNode)
    
let 
    walletDb = open("wallet.db", "", "", "")
    knownNodes = getNodes(walletDb)

proc createWallet(db: DbConn): tuple[pk, sk: string] =
    let 
        (publicKey, secretKey) = cryptoSignKeypair()

    db.exec(
        sql"""
            INSERT INTO wallets (secretKey, publicKey, balance) VALUES (?, ?, 0)
        """, encode(secretKey), publicKey.toBlockChainAddress
    )

    result.pk = publicKey
    result.sk = secretKey

proc selectLoadedWallet(db: DbConn, amount: int): tuple[id: int, pk, sk: string] =
    let dbResult = db.getRow(
        sql"""
            SELECT id, publicKey, secretKey FROM wallets WHERE balance >= ?
        """, amount
    )
    if dbResult[0].len > 0:
        result.id = parseInt dbResult[0]
        result.pk = decode dbResult[1]
        result.sk = decode dbResult[2]

proc adjustBalance(db: DbConn, sender, receiver: string, amount: int) =
    # db.exec(
    #     sql"""
    #         UPDATE wallets SET balance = balance - ? WHERE id = ?
    #     """, amount, walletId
    # )
    db.exec(sql"BEGIN")
    db.exec(
        sql"""
            UPDATE ledger SET balance = (balance - ?) WHERE publicKey = ? 
        """, amount, sender
    )

    db.exec(
        sql"""
            UPDATE ledger  SET balance = (balance + ?) WHERE publicKey = ?
        """, amount, receiver
    )

    db.exec(sql"COMMIT")

func initTransaction(sender, receiver: string, amount: int): Transaction =
    result = Transaction(sender: sender, receiver: receiver, amount: amount)

func `$`(transaction: Transaction): string =
    result = &"sender {transaction.sender}\nreceiver {transaction.receiver}\namount {transaction.amount}\n"

proc sendTransaction(node: BlockChainNode, transaction: Transaction, signature: string) =
    let 
        ip = node.ip
        transactionData = transactionHeader(len($transaction) + len(signature) + 11) & $transaction & &"signature {signature}\n"
    
    echo transactionData
    networkSocket.connect(ip, protocolPort)
    networkSocket.send(transactionData)
    let 
        response = networkSocket.recvLine()
    echo response
    
    let miningResult = networkSocket.recvLine()
    echo miningResult

proc broadcastTransaction(transaction: Transaction, signature: string) =
    for node in knownNodes:
        node.sendTransaction(transaction, signature)

proc signature(transaction: Transaction, sk: string): string =
    result = encode(sk.cryptoSign($transaction))

proc sendTransaction(receiver: string, amount: int) =
    let (walletId, walletPk, walletSk) = walletDb.selectLoadedWallet(amount)

    if walletSk != "" and walletPk != "":
        let transaction = initTransaction(walletPk.toBlockChainAddress, receiver, amount)
        broadcastTransaction(transaction, signature(transaction, walletSk))
        walletDb.adjustBalance(walletPk, receiver, amount) #looks sus, because what if the transaction never goes through
    else:
        echo "INSUFFICIENT FUNDS: None of your wallets can send ", amount, " shitcoins"


when isMainModule:
    let (pk, sk) = walletDb.createWallet()
    let receiverAddress = encode(pk)
    sendTransaction(receiverAddress, 1)
    # echo walletDb.selectLoadedWallet(20)