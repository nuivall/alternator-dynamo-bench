#!/bin/bash
set -euo pipefail

# Scripts which runs YCSB on all loader instances
#
# Supported arguments:
#
# * (unconditional right now) Run write throughput benchmark
# * isolation:  set to "forbid_rmw" for writes without LWT (the default),
#               or to "always_use_lwt" (with LWT).
# * aws:        if empty (default), benchmark the Scylla servers.
#               If "aws is set, we test the real DynamoDB in that Amazon
#               region (e.g., "aws=us-east-1").
# * wcu:        set the maximum rate sent by each loader
#               to wcu / number_of_loaders.
# * fieldcount, fieldlength: Control the size of each item, as fieldcount
#               attributes of size fieldlength each. The defaults are 10,256.
# * time:       how much time (in seconds) to run the test. Defaults to 300.

isolation="${isolation:-'forbid_rmw'}"
aws="${aws:-'us-east-1'}"
wcu="${wcu:-}"
fieldcount="${fieldcount:-'10'}"
fieldlength="${fieldlength:-'256'}"
time="${time:-'300'}"

# Binary path on a loader machines
YCSB_DIR='/opt/scylla/ycsb-dynamodb-binding-0.17.0'
YCSB=${YCSB_DIR}'/bin/ycsb'

loaders_json=(`terraform output -json loader_public_ips`)
readarray -t loaders < <(jq -r '.[]' <<<"$loaders_json")
declare -p loaders

TMPDIR=/tmp/bench-$$
mkdir ${TMPDIR}
echo "Keeping stats in ${TMPDIR}"

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# TODO: add support for alternator
nodes=(a b c)

# Number of YCSB loaders to use per loader/server combination.
# In other words, each loader will run MULT*nservers ycsb processes, and each
# server will be loaded by MULT*nloaders ycsb processes.
# TODO: I don't understand why with say fieldcount=1 MULT=2 it takes a very
# long time to get higher results than MULT=1.
MULT=${MULT:-1}

if ! test -z "$wcu"
then
    nycsb=$((${#loaders[@]} * ${#nodes[@]} * MULT))
    target="-target $((wcu/nycsb))"
else
    target=
fi

typeset -i i=0
for loader in ${loaders[@]}
do
    for node in ${nodes[@]}
    do
        case $aws in
        "") # Scylla:
            endpoint=http://$node:8080
            ;;
        *)  # AWS:
            endpoint=http://dynamodb.$aws.amazonaws.com
            ;;
        esac
        for mult in `seq $MULT`
        do
            let ++i
            # For description of the following options, see
            # https://github.com/brianfrankcooper/YCSB/blob/master/dynamodb/conf/dynamodb.properties
            # NOTE: YCSB currently has two modes - "HASH" - with single-row
            # partitions - and "HASH_AND_RANGE" - where we have a *single*
            # partition and all the items in it. The HASH_AND_RANGE mode is
            # worthless for benchmarking because it has a single hot
            # partition.
            ${SCRIPTPATH}/ec2-ssh $loader "$YCSB run dynamodb -P $YCSB_DIR/workloads/workloada -threads 100 \
            ${target} \
            -p recordcount=1000000 \
            -p insertstart=$((i*1000000 )) \
            -p requestdistribution=uniform \
            -p fieldcount=${fieldcount} \
            -p fieldlength=${fieldlength} \
            -p readproportion=0 \
            -p updateproportion=0 \
            -p scanproportion=0 \
            -p insertproportion=1 \
            -p maxexecutiontime=${time} \
            -p operationcount=999999999 \
            -p measurementtype=hdrhistogram \
            -p dynamodb.endpoint=${endpoint} \
            -p dynamodb.connectMax=200 \
            -p requestdistribution=uniform \
            -p dynamodb.consistentReads=true \
            -p dynamodb.primaryKey=p \
            -p dynamodb.primaryKeyType=HASH \
            -s" > $TMPDIR/$loader-$node-$mult 2>&1 &
        done
    done
done

# Wait for all the loaders started above to finish.
# TODO: catch interrupt and kill all the loaders.
wait

# Add the average (over the entire run) of the throughput of each loader.
# For the result to make sense, the loaders should all start and stop at
# roughly the same time, and the run must be long enough:
# * "time" of 300 (5 minutes) seems to give around 95% of the throughput
# * "time" of 600 (10 minutes) seems to give around 98% of the throughput
# A more accurate approach would be to calculate # the total throughput at
# each second and then graph (and average) those, but that's more complicated.
fgrep -h '[OVERALL], Throughput(ops/sec)' $TMPDIR/* |
    awk '{sum+=$3} END {print sum}'
