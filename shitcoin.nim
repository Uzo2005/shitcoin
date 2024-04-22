









# import ./node/node, ./client/client
import base58/bitcoin
import libsodium/sodium
import libsodium/sodium_sizes
import checksums/sha2


let 
    (pk, sk) = crypto_sign_keypair()


echo encode(pk)
echo encode(sk)

