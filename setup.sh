#!/bin/sh

set -xe

nimble install
nim r init.nim #setup databases
cd node/
nim r miner.nim #mine the genesis block
