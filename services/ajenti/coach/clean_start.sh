#!/bin/bash

rm ceph/*
ajenti-dev-multitool --build
ajenti-dev-multitool --run-dev
