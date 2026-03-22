#!/bin/sh

if [ -f /vault/policies/vault-mist.hcl ]; then
    echo "Found vault policies file"
else
    cp /init/policies/vault-mist.hcl /vault/policies
    echo "Initialized vault policies file"
fi

INIT_LOG=/vault/init.log
UNSEAL_TOKEN_PATH=/vault/config/unseal_token
ROOT_TOKEN_PATH=/vault/config/root_token
# ROLE_TOKEN_PATH=/approle/token
ROLE_ID_PATH=/approle/role_id
SECRET_ID_PATH=/approle/secret_id

if [ -f "$UNSEAL_TOKEN_PATH" ]; then
    echo "Unsealing vault"
    vault operator unseal "$(cat $UNSEAL_TOKEN_PATH)"
    export VAULT_TOKEN="$(cat $ROOT_TOKEN_PATH)"
    vault policy write mist /vault/policies/vault-mist.hcl
    vault write auth/approle/role/mist token_num_uses=0 token_policies=mist
    ROLE_ID=$(vault read auth/approle/role/mist/role-id -format=json |jq .data.role_id -r)
    SECRET_ID=$(vault write -f auth/approle/role/mist/secret-id -format=json | jq .data.secret_id -r)
    # ROLE_TOKEN=$(vault write auth/approle/login secret_id=$SECRET_ID role_id=$ROLE_ID -format=json | jq .auth.client_token -r)
    # echo $ROLE_TOKEN > $ROLE_TOKEN_PATH
    echo $ROLE_ID > $ROLE_ID_PATH
    echo "Role Id: $ROLE_ID"
    echo $SECRET_ID > $SECRET_ID_PATH
    echo "Secref Id: $SECRET_ID"
else
    echo "Initializing Vault server"
    vault operator init -key-shares=1 -key-threshold=1 -format=json > "$INIT_LOG"
    export UNSEAL_TOKEN=$(cat $INIT_LOG | jq .unseal_keys_b64[0] -r)
    export ROOT_TOKEN=$(cat $INIT_LOG | jq .root_token -r)
    echo "$ROOT_TOKEN" > "$ROOT_TOKEN_PATH"
    echo "$UNSEAL_TOKEN" > "$UNSEAL_TOKEN_PATH"
    vault operator unseal "$UNSEAL_TOKEN"
    export VAULT_TOKEN="$ROOT_TOKEN"
    # Wait for vault to report unsealed+ready before proceeding
    for i in $(seq 1 30); do
        vault status >/dev/null 2>&1 && break
        sleep 1
    done
    vault secrets enable -path="kv1" kv
    vault policy write mist /vault/policies/vault-mist.hcl
    vault auth enable approle
    vault write auth/approle/role/mist token_num_uses=0 token_policies=mist
    ROLE_ID=$(vault read auth/approle/role/mist/role-id -format=json |jq .data.role_id -r)
    SECRET_ID=$(vault write -f auth/approle/role/mist/secret-id -format=json | jq .data.secret_id -r)
    # ROLE_TOKEN=$(vault write auth/approle/login secret_id=$SECRET_ID role_id=$ROLE_ID -format=json | jq .auth.client_token -r)
    # echo $ROLE_TOKEN > $ROLE_TOKEN_PATH
    echo $ROLE_ID > $ROLE_ID_PATH
    echo "Role Id: $ROLE_ID"
    echo $SECRET_ID > $SECRET_ID_PATH
    echo "Secref Id: $SECRET_ID"
fi
echo "Done!"

