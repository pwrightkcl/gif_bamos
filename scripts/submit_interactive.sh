#!/bin/bash

runai submit risaps \
  -i aicregistry:5000/pwright:risaps0.4 \
  --run-as-user \
  --interactive \
  --attach \
  --gpu 0 \
  --large-shm \
  -v /nfs/project/RISAPS:/nfs/project/RISAPS
