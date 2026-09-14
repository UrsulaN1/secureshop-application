# US-036: least-privilege policy - the app can only read its own secret path
path "secret/data/secureshop/dev/*" {
  capabilities = ["read"]
}

path "secret/data/secureshop/staging/*" {
  capabilities = ["read"]
}

# No write/delete capability granted to the application identity.
