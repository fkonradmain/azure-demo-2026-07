#!/bin/sh

az storage account create -n tfstatefk
az storage container create -n tfstatefk --account-name tfstatefk
