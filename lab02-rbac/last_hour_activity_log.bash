#!/bin/bash

MG_ID="az104-mg1"
START_TIME=$(date -u -d '1 hour ago' +'%Y-%m-%dT%H:%M:%SZ')
END_TIME=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

az rest --method get --url "https://management.azure.com/providers/Microsoft.Management/managementGroups/$MG_ID/providers/microsoft.insights/eventtypes/management/values?api-version=2017-03-01-preview&\$filter=eventTimestamp ge '$START_TIME' and eventTimestamp le '$END_TIME'"\
| jq -r '.value[] | [.operationName.localizedValue, .status.localizedValue, .eventTimestamp] | @tsv' \
| column -t -s $'\t'
