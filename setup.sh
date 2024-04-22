#!/bin/sh

set -xe

nim r init.nim #setup databases
cd node/
nim r miner.nim #mine the genesis block
