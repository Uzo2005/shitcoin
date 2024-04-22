when isMainModule:
    import db_connector/db_sqlite

    let 
        clientDB = open("client/wallet.db", "", "", "")
        nodeDB = open("node/node.db", "", "", "")

    clientDB.exec(
        sql"""
            CREATE TABLE IF NOT EXISTS wallets (
                id INTEGER PRIMARY KEY ASC, 
                publicKey TEXT NOT NULL,
                secretKey TEXT NOT NULL,
                balance INTEGER NOT NULL
            )
        """
    )
    clientDB.exec(
        sql"""
            CREATE TABLE IF NOT EXISTS nodes (
                id INTEGER PRIMARY KEY ASC, 
                ip TEXT NOT NULL
            )
        """
    )
    
    nodeDB.exec(
        sql"""
            CREATE TABLE IF NOT EXISTS peers (
                id INTEGER  PRIMARY KEY ASC,
                ip TEXT NOT NULL
            )
        """
    )

    nodeDB.exec(
        sql"""
            CREATE TABLE IF NOT EXISTS ledger (
                id INTEGER  PRIMARY KEY ASC,
                address TEXT NOT NULL,
                balance INTEGER NOT NULL
            )
        """
    )

    nodeDB.exec(
        sql"""
            CREATE TABLE IF NOT EXISTS blocks (
                blockId INTEGER PRIMARY KEY ASC,
                senderAddress TEXT NOT NULL,
                receiverAddress TEXT NOT NULL,
                amount INTEGER NOT NULL,
                nonce INTEGER NOT NULL,
                previousBlockHash TEXT NOT NULL,
                blockHash TEXT NOT NULL
            )
        """
    )
    
    clientDB.exec( #coinbase
        sql"""
            INSERT INTO wallets (publicKey, secretKey, balance) VALUES ("FAYKnZ5g733SHm5ouBsRSnKWhaUsZqmZynNQUsJnxsFg", "3VbdkUEPssmkHQiA4jux5tX2EtGy4KxvMzhY2jVzdgYY5uDCaAKaqWv5241eAFGjezHRcyWhf3VHqvWYCvR9mxoU", 100)
        """
    )

    clientDB.exec( #seed first node
        sql"""
            INSERT INTO nodes (ip) VALUES ("127.0.0.1")
        """
    )

    nodeDb.exec( #coinbase
        sql"""
            INSERT INTO ledger (address, balance) VALUES ("FAYKnZ5g733SHm5ouBsRSnKWhaUsZqmZynNQUsJnxsFg", 100)
        """
    )


    clientDB.close()
    nodeDB.close()
