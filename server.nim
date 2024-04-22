import asynchttpserver, asyncdispatch, times
import db_connector/db_sqlite

let 
    walletDB = open("client/wallet.db", "", "", "")
    nodeDB = open("node/node.db", "", "", "")

when defined(release):
    const port = Port(80)
else:
    const port = Port(2024)

proc main {.async.} =
    var server = newAsyncHttpServer()

    proc cb(req: Request) {.async.} =
      let headers = {"Content-type": "text/plain; charset=utf-8"}

      case req.url.path:
        of "/":
            const response = """
                ROUTES:
                    /blockchain -> current state of the blockchain
                    /wallet -> current state of the user's wallet address
            """
            await req.respond(Http200, response,  headers.newHttpHeaders())
        of "/blockchain":
            var response = ""
            response.add("PEER NODES THIS NODE BROADCASTS TO\n-----------------------------------------\n")
            response.add("id \t | IP Address \t\t\t")
            response.add("\n----------------------------\n")
            for peer in nodeDB.fastRows(sql"SELECT * FROM peers"):
                response.add(peer[0] & "\t | " & peer[1] & "\t\t\t")
                response.add("\n---------------------------------------------\n")

            response.add("\n\n")

            response.add("PRIVATE LEDGER THIS NODE MAINTAINS AND USES TO VERIFY TRANSACTIONS \n-----------------------------------------\n")
            
            for record in nodeDB.fastRows(sql"SELECT * FROM ledger"):
                response.add("Record Id: " & record[0] & "\n")
                response.add("Address: " & record[1] & "\n")
                response.add("Balance: " & record[2] & "\n")
                response.add("\n---------------------------------------------\n")

            response.add("\n\n")

            response.add("BLOCKCHAINS OF TRANSACTIONS AS OF " & $now() & "\n-----------------------------------------\n")
            for sblock in nodeDB.fastRows(sql"SELECT * FROM blocks"):
                response.add("Block Id: " & sblock[0] & "\n")
                response.add("Sender Address: " & sblock[1] & "\n")
                response.add("Receiver Address: " & sblock[2] & "\n")
                response.add("Amount: " & sblock[3] & "\n")
                response.add("Nonce: " & sblock[4] & "\n")
                response.add("Previous Block Hash: " & sblock[5] & "\n")
                response.add("Block Hash: " & sblock[6] & "\n")
                response.add("---------------------------------------------\n")

            await req.respond(Http200, response,  headers.newHttpHeaders())
        of "/wallet":
            var response = ""
            response.add("NODES THIS WALLET STORE BROADCASTS TO\n-----------------------------------------\n")
            for node in walletDb.fastRows(sql"SELECT * FROM nodes"):
                response.add("Node Id: " & node[0] & "\n")
                response.add("Node IP Address: " & node[1] & "\n")
                response.add("============================================\n")

            response.add("\n\n")
            response.add("WALLETS\n-----------------------------------------\n")
            for wallet in walletDb.fastRows(sql"SELECT * FROM wallets"):
                response.add("Wallet Id: " & wallet[0] & "\n")
                response.add("Wallet Public Key: " & wallet[1] & "\n")
                response.add("Wallet Secret Key: " & wallet[2] & "\n")
                response.add("Wallet Balance: " & wallet[3] & "\n")
                response.add("============================================\n")
            
            await req.respond(Http200, response,  headers.newHttpHeaders())




    server.listen(port)
    let port = server.getPort
    echo "Server Is Running On localhost:" & $port.uint16 & "/"
    while true:
      if server.shouldAcceptRequest():
        await server.acceptRequest(cb)
      else:
        # too many concurrent connections, `maxFDs` exceeded
        # wait 500ms for FDs to be closed
        await sleepAsync(500)


waitFor main()